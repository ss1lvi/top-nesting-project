import json
import os
import markovify
import boto3
from botocore.exceptions import ClientError
import logging
import datetime
from slugify import slugify

logger = logging.getLogger()
logger.setLevel(logging.INFO)

my_region = os.environ['MY_REGION']
s3_client = boto3.client('s3', region_name=my_region)
bucket_name = os.environ['BUCKET_NAME']
title_corpus = os.environ['TITLE_CORPUS']
body_corpus = os.environ['BODY_CORPUS']

logger.info(f'aws_region: {my_region}')
logger.info(f'bucket_name: {bucket_name}')
logger.info(f'title_corpus: {title_corpus}')
logger.info(f'body_corpus: {body_corpus}')


def markov_title():

    # read corpus from S3
    # decode the file to string
    # markovify that text into a model

    obj = s3_client.get_object(Bucket=bucket_name, Key=title_corpus)
    text = obj['Body'].read().decode('utf-8')
    model = markovify.NewlineText(text)

    # then make a title sentence

    return model.make_short_sentence(140)


def markov_body():

    # read corpus from S3
    # decode the file to string
    # markovify that text into a model

    obj = s3_client.get_object(Bucket=bucket_name, Key=body_corpus)
    text = obj['Body'].read().decode('utf-8')
    # model = markovify.Text(text)
    model = markovify.NewlineText(text)

    # print a paragraph
    sents = []
    for i in range(20):
        sents.append(model.make_sentence())

    return " ".join(sents)


def markov_format(title, body):

    # takes the title and the body and turns them into a blog post

    # needs to be in this format:
    #
    # ---
    # title: "$TITLE"
    # date: "$(date +%FT%TZ)"
    # description: "test article number $i"
    # categories: [paragraph]
    # comments: true
    # ---
    #
    # $BODY

    logger.info(f'writing article to /tmp/index.md')

    with open(f'/tmp/index.md', 'w') as f:
        f.write(f'---\n')
        f.write(f'title: {title}\n')
        f.write(f'date: {datetime.datetime.now().isoformat()}\n')
        f.write(f'description: {title}\n')
        f.write(f'categories: [paragraph]\n')
        f.write(f'comments: true\n')
        f.write(f'---\n')
        f.write(f'\n')
        f.write(f'{body}\n')


def upload_file(file_name, bucket, object_name=None):
    """Upload a file to an S3 bucket

    :param file_name: File to upload
    :param bucket: Bucket to upload to
    :param object_name: S3 object name. If not specified then file_name is used
    :return: True if file was uploaded, else False
    """

    # If S3 object_name was not specified, use file_name
    if object_name is None:
        object_name = file_name

    # Upload the file
    
    try:
        response = s3_client.upload_file(file_name, bucket, object_name)
    except ClientError as e:
        logging.error(e)
        return False
    return True


def writer(event, context):

    # create an article title
    title = markov_title()
    logger.info(f'title: {title}')

    # create an article body
    body = markov_body()
    logger.info(f'body: {body}')

    # combine title and body into a new post
    markov_format(title, body) # write new post to /tmp/index.md

    # create an article slug for the folder name
    slug = slugify(title, max_length=24)
    filename = f'{slug}/index.md'

    # upload the new article to s3
    upload_file('/tmp/index.md',f'{bucket_name}',f'{filename}')
    logger.info(f'uploaded index.md to s3://{bucket_name}/{slug}')


    content = {
        "message": f"A new article is born!",
        "input": event,
        "title": f"{title}",
        "body": f"{body}",
        "slug": f"{slug}"
    }

    return {"statusCode": 200, "body": content}
