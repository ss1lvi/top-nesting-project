import os
import json
import git
import boto3
import logging

def publisher(event, context):

    logger = logging.getLogger()
    logger.setLevel(logging.INFO)

    logger.info(event)
    logger.info(context)

    my_region = os.environ['MY_REGION']
    s3 = boto3.resource('s3', region_name=my_region)
    bucket_name = os.environ['BUCKET_NAME']
    article_slug = event['articleSlug']

    logger.info(f'aws_region: {my_region}')
    logger.info(f'bucket_name: {bucket_name}')
    logger.info(f'article: {article_slug}')

    # get SSH key
    ssm = boto3.client('ssm')
    parameter = ssm.get_parameter(Name='git-lambda', WithDecryption=True)
    private_key = parameter['Parameter']['Value']

    # clean up /tmp
    os.system("rm -rf /tmp/*")

    # save SSH key and chmod permissions
    with open('/tmp/id_rsa', 'w') as outfile:
        outfile.write(f'{private_key}\n')
    os.chmod('/tmp/id_rsa', 0o400) # leading 0 in python2 and 0o in python 3 defines octal

    # os.environ['GIT_SSH_COMMAND'] = 'ssh -o StrictHostKeyChecking=no -i /tmp/id_rsa'
    # logger.info(f"GIT_SSH_COMMAND= {os.environ['GIT_SSH_COMMAND']}")
    repo = git.Repo.clone_from('git@github.com:ss1lvi/nesting-blog.git', '/tmp/nesting-blog', branch='test')
    logger.info(f'cloned git repo to /tmp/')

    local_dir = '/tmp/nesting-blog/content/blog/'
    bucket = s3.Bucket(bucket_name)
    for object in bucket.objects.filter(Prefix = article_slug):
        os.makedirs(os.path.dirname(f'{local_dir}{object.key}'), exist_ok=True)
        bucket.download_file(object.key, f'{local_dir}{object.key}')
        logger.info(f'downloaded {object.key} to {local_dir}')

    repo.git.add(all=True)
    repo.git.commit('-m','via python')
    repo.git.push()
    logger.info(f'pushed new commit to git')

    content = {
        "message": "New article published successfully!",
        "article": {article_slug},
        "input": event
    }

    return {"statusCode": 200, "body": content}
