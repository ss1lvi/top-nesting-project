import os
import json
import git
import boto3
import logging

def publisher(event, context):

    logger = logging.getLogger()
    logger.setLevel(logging.INFO)

    my_region = os.environ['MY_REGION']
    s3 = boto3.resource('s3', region_name=my_region)
    bucket_name = os.environ['BUCKET_NAME']
    article_slug = 'articleSlug'

    logger.info(f'aws_region: {my_region}')
    logger.info(f'bucket_name: {bucket_name}')

    repo = git.Repo.clone_from('git@github.com:ss1lvi/nesting-blog.git', '/tmp/nesting-blog', branch='test')
    
    local_dir = '/tmp/nesting-blog/content/blog/'
    bucket = s3.Bucket(bucket_name)
    for object in bucket.objects.filter(Prefix = article_slug):
        os.makedirs(os.path.dirname(f'{local_dir}{object.key}'), exist_ok=True)
        bucket.download_file(object.key, f'{local_dir}{object.key}')

    repo.git.add(all=True)
    repo.git.commit('-m','via python')
    repo.git.push()
    
    body = {
        "message": "Go Serverless v2.0! Your function executed successfully!",
        "input": event,
    }

    return {"statusCode": 200, "body": json.dumps(body)}
