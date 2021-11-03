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
    parameter_name = os.environ['KEY_PARAMETER_NAME']
    git_repo_url = os.environ['GIT_REPO_URL']
    git_user_name = os.environ['GIT_USER_NAME']
    git_user_email = os.environ['GIT_USER_EMAIL']
    blog_root = git_repo_url.split('/')[1].replace('.git','')
    blog_path = os.environ['BLOG_PATH']

    logger.info(f'aws_region: {my_region}')
    logger.info(f'bucket_name: {bucket_name}')
    logger.info(f'article: {article_slug}')
    logger.info(f'parameter_name: {parameter_name}')
    logger.info(f'git_repo_url: {git_repo_url}')
    logger.info(f'git_user_name: {git_user_name}')
    logger.info(f'git_user_email: {git_user_email}')
    logger.info(f'blog_path: {blog_path}')

    # clean up /tmp
    os.system("rm -rf /tmp/*")

    # get SSH key
    ssm = boto3.client('ssm')
    parameter = ssm.get_parameter(Name=parameter_name, WithDecryption=True)
    private_key = parameter['Parameter']['Value']

    # save SSH key and chmod permissions
    with open('/tmp/id_rsa', 'w') as outfile:
        outfile.write(f'{private_key}\n')
    os.chmod('/tmp/id_rsa', 0o400) # leading 0 in python2 and 0o in python 3 defines octal

    # clone git repo and set user/email
    repo = git.Repo.clone_from(git_repo_url, f'/tmp/{blog_root}', branch='test')
    repo.config_writer().set_value("user", "name", git_user_name).release()
    repo.config_writer().set_value("user", "email", git_user_email).release()
    logger.info(f'cloned git repo to /tmp/')

    # download article from s3 and place in the blog folder
    local_dir = f'/tmp/{blog_root}{blog_path}'
    bucket = s3.Bucket(bucket_name)
    for object in bucket.objects.filter(Prefix = article_slug):
        os.makedirs(os.path.dirname(f'{local_dir}{object.key}'), exist_ok=True)
        bucket.download_file(object.key, f'{local_dir}{object.key}')
        logger.info(f'downloaded {object.key} to {local_dir}')

    # commit and push to git
    repo.git.add(all=True)
    repo.git.commit('-m',f'added {article_slug} via python')
    repo.git.push()
    logger.info(f'pushed new commit to git')

    content = {
        "message": "New article published successfully!",
        "article": f"{article_slug}",
        "input": event
    }

    return {"statusCode": 200, "body": content}
