#!/bin/bash

######################################################
#
# Author : Kallol Bairagi
# 
# Date : 11-Nov-2023
# 
# Description : Whenever a file is uploaded in 
#               s3 bucket, we trigger a notification 
#               to our email id
#
#
######################################################

# debug mode
set -x

# store aws account id in a variable
# def: sts is security token service
aws_account_id=$(aws sts get-caller-identity | jq -r ".Account")

# print the aws account id
echo "AWS Account Id: $aws_account_id"

# set aws configs
aws_region="us-east-1"

# set S3 bucket name
bucket_name="s3-kallolb-bucket-1"

# set Lambda function name
lambda_func_name="s3-lambda-kallolb-function-1"

# set IAM role name
role_name="s3-sns-kallolb-role-1"

# set SNS topic name
sns_topic_name="s3-lambda-sns-kallolb-1"

# set email address to send notification to
email_address="kallol.bairagi77@gmail.com"


# create IAM role for the project and attach a role policy to it
# role policy: to allow the principal to have access to aws services - lambda, s3 and sns
role_response=$(aws iam create-role --role-name "$role_name" --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [{
    "Action": "sts:AssumeRole",
    "Effect": "Allow",
    "Principal": {
      "Service": [
        "lambda.amazonaws.com",
	"s3.amazonaws.com",
	"sns.amazonaws.com"
      ]
    }
  }]
}')

# extract the role ARN from the JSON role response and store it in a variable
role_arn=$(echo "$role_response" | jq -r '.Role.Arn')

# print the role ARN
echo "Role ARN : $role_arn"

# attach permissions to these roles
# this could be done from the above statement as well when we were creating the IAM role
aws iam attach-role-policy --role-name "$role_name" --policy-arn arn:aws:iam::aws:policy/AWSLambda_FullAccess 
aws iam attach-role-policy --role-name "$role_name" --policy-arn arn:aws:iam::aws:policy/AmazonSNSFullAccess

# create a S3 bucket
bucket_response=$(aws s3api create-bucket --bucket "$bucket_name" --region "$aws_region")

# print the S3 bucket response 
echo "S3 bucket creation response : $bucket_response"

# upload a file to S3 bucket
upload_filename="2023-11-11-upload-file.txt"
aws s3 cp ./files/2023-11-11-upload-file.txt s3://"$bucket_name"/"$upload_filename"

# create a zip file to upload a Lambda function
zip -r s3-lambda-kallolb-function-1.zip ./s3-lambda-kallolb-function-1

sleep 5

# create a Lambda function
# aws takes care of extracting the zip file
aws lambda create-function \
  --function-name "$lambda_func_name" \
  --region "$aws_region" \
  --runtime "python3.8" \
  --handler "$lambda_func_name/$lambda_func_name.lambda_handler" \
  --memory-size 128 \
  --timeout 30 \
  --role "arn:aws:iam::$aws_account_id:role/$role_name" \
  --zip-file "fileb://./s3-lambda-kallolb-function-1.zip" 

# add permisson to S3 bucket to invoke Lamnda function
aws lambda add-permission \
  --function-name "$lambda_func_name" \
  --statement-id "s3-lambda-sns-kallolb-1" \
  --action "lambda:InvokeFunction" \
  --principal s3.amazonaws.com \
  --source-arn "arn:aws:s3:::$bucket_name"

# create a S3 event trigger for the Lambda function 
aws s3api put-bucket-notification-configuration \
  --region "$aws_region" \
  --bucket "$bucket_name" \
  --notification-configuration '{
    "LambdaFunctionConfigurations": [{
      "LambdaFunctionArn": "arn:aws:lambda:$aws_region:$aws_account_id:function:$lambda_func_name",
      "Events":["s3:ObjectCreated:*"] 
    }]
  }'

# create a SNS topic and save the topic ARN to a variable
topic_arn=$(aws sns create-topic --name "$sns_topic_name" --output json | jq -r '.TopicArn') 

# print the topic ARN
echo "SNS Topic ARN : $topic_arn"

# Trigger SNS topic using Lambda function
# Add SNS publish permission to the Lambda function
aws sns subscribe \
  --topic-arn "$topic_arn" \
  --protocol email \
  --notification-endpoint "$email_address"

aws sns publish \
  --topic-arn "$topic_arn" \
  --subject "New file added to S3 bucket" \
  --message "Greetings from Seven Piece !! A new file has been added to your S3 bucket : $bucket_name"


