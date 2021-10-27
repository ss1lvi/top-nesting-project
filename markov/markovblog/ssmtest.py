import os
import json
import git
import boto3
import logging

# get SSH key
ssm = boto3.client('ssm')
parameter = ssm.get_parameter(Name='git-lambda', WithDecryption=True)
private_key = parameter['Parameter']['Value']

# save SSH key in /tmp and chmod permissions
with open('/.ssh/id_rsa', 'w') as outfile:
    outfile.write(private_key)
os.chmod('./id_rsa', 0o400) # leading 0 in python2 and 0o in python 3 defines octal
