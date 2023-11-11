import boto3
import json

def lambda_handler(event, context):
    
    # Extract information from the S3 event trigger
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    object_key = event['Records'][0]['s3']['object']['key']

    # print operation 
    print(f"File '{object_key}' will be uploaded to '{bucket_name}'")

    # send notification via SNS
    sns_client = boto3.client('sns')
    topic_arn = 'arn:aws:sns:us-east-1:<account-id>:s3-lambda-sns-kallolb'
    sns_client.publish(
      TopicArn = topic_arn,
      Subject = 'New file added to S3 bucket',
      Message = f"File '{object_key}' will be uploaded to '{bucket_name}'"
    )

    return {
      'statusCode': 200,
      'body': json.dumps('Lambda function executed successfully !!')
    }

