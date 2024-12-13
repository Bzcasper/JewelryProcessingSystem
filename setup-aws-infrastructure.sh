#!/bin/bash

# Exit on error
set -e

echo "Setting up AWS infrastructure for jewelry processing system..."

export CLOUDINARY_CLOUD_NAME="dpciejkg5"
export CLOUDINARY_API_KEY="932779144596342"
export CLOUDINARY_API_SECRET="cwIkqaDjk_vV4m-KjpvVhw7MjP4"

# Generate random suffix for globally unique bucket names
SUFFIX=$(date +%s | cut -c 6-10)
INPUT_BUCKET="jewelry-images-input-${SUFFIX}"
OUTPUT_BUCKET="jewelry-images-processed-${SUFFIX}"

# Set your region
REGION="us-east-1"

# Create S3 buckets
echo "Creating S3 buckets..."
aws s3api create-bucket \
    --bucket $INPUT_BUCKET \
    --region $REGION

aws s3api create-bucket \
    --bucket $OUTPUT_BUCKET \
    --region $REGION

# Create DynamoDB table
echo "Creating DynamoDB table..."
aws dynamodb create-table \
    --table-name jewelry-metadata \
    --attribute-definitions AttributeName=imageId,AttributeType=S \
    --key-schema AttributeName=imageId,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region $REGION

# Create IAM role for Lambda
echo "Creating IAM role for Lambda..."
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role \
    --role-name jewelry-processor-role \
    --assume-role-policy-document file://trust-policy.json

# Create IAM policy for Lambda
echo "Creating IAM policy for Lambda..."
cat > lambda-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::${INPUT_BUCKET}/*",
                "arn:aws:s3:::${OUTPUT_BUCKET}/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:PutItem",
                "dynamodb:GetItem",
                "dynamodb:UpdateItem",
                "dynamodb:DeleteItem",
                "dynamodb:Query"
            ],
            "Resource": "arn:aws:dynamodb:${REGION}:*:table/jewelry-metadata"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        }
    ]
}
EOF

aws iam put-role-policy \
    --role-name jewelry-processor-role \
    --policy-name jewelry-processor-policy \
    --policy-document file://lambda-policy.json

# Create Lambda function
echo "Creating Lambda function..."
mkdir -p lambda
cat > lambda/jewelry_processor.py << EOF
import json
import boto3
import os
import cloudinary
import cloudinary.uploader

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb').Table('jewelry-metadata')

def lambda_handler(event, context):
    try:
        # Get bucket and key from event
        record = event['Records'][0]
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        
        # Download from S3
        download_path = f"/tmp/{key}"
        s3.download_file(bucket, key, download_path)
        
        # Process image and upload to Cloudinary
        cloudinary.config(
            cloud_name=os.environ['CLOUDINARY_CLOUD_NAME'],
            api_key=os.environ['CLOUDINARY_API_KEY'],
            api_secret=os.environ['CLOUDINARY_API_SECRET']
        )
        
        upload_result = cloudinary.uploader.upload(download_path)
        
        # Store metadata in DynamoDB
        dynamodb.put_item(
            Item={
                'imageId': key,
                'cloudinaryUrl': upload_result['secure_url'],
                'metadata': {
                    'format': upload_result['format'],
                    'size': upload_result['bytes'],
                    'width': upload_result['width'],
                    'height': upload_result['height']
                }
            }
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Image processed successfully',
                'imageUrl': upload_result['secure_url']
            })
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }
EOF

# Install dependencies
cd lambda
pip install --target ./package cloudinary boto3
cd package
zip -r ../lambda.zip .
cd ..
zip -g lambda.zip jewelry_processor.py
cd ..

# Create Lambda function
echo "Deploying Lambda function..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/jewelry-processor-role"

# Wait for role to propagate
echo "Waiting for IAM role to propagate..."
sleep 10

aws lambda create-function \
    --function-name jewelry-processor \
    --runtime python3.9 \
    --handler jewelry_processor.lambda_handler \
    --role $ROLE_ARN \
    --zip-file fileb://lambda/lambda.zip \
    --timeout 30 \
    --memory-size 256 \
    --environment Variables="{CLOUDINARY_CLOUD_NAME=your_cloud_name,CLOUDINARY_API_KEY=your_api_key,CLOUDINARY_API_SECRET=your_api_secret}" \
    --region $REGION

# Add S3 trigger to Lambda
echo "Adding S3 trigger to Lambda..."
aws lambda add-permission \
    --function-name jewelry-processor \
    --statement-id S3Trigger \
    --action lambda:InvokeFunction \
    --principal s3.amazonaws.com \
    --source-arn "arn:aws:s3:::${INPUT_BUCKET}" \
    --region $REGION

# Configure S3 bucket notification
cat > notification.json << EOF
{
    "LambdaFunctionConfigurations": [
        {
            "LambdaFunctionArn": "arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:jewelry-processor",
            "Events": ["s3:ObjectCreated:*"]
        }
    ]
}
EOF

aws s3api put-bucket-notification-configuration \
    --bucket $INPUT_BUCKET \
    --notification-configuration file://notification.json

# Create API Gateway
echo "Creating API Gateway..."
API_ID=$(aws apigateway create-rest-api \
    --name jewelry-api \
    --description "API for jewelry image processing" \
    --query 'id' --output text)

ROOT_RESOURCE_ID=$(aws apigateway get-resources \
    --rest-api-id $API_ID \
    --query 'items[?path==`/`].id' --output text)

# Create resource and method for file upload
RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ROOT_RESOURCE_ID \
    --path-part "upload" \
    --query 'id' --output text)

aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method POST \
    --authorization-type NONE

# Deploy API
aws apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name prod

# Clean up temporary files
rm -f trust-policy.json lambda-policy.json notification.json
rm -rf lambda

echo "Setup complete! Infrastructure has been created successfully."
echo "Input bucket: $INPUT_BUCKET"
echo "Output bucket: $OUTPUT_BUCKET"
echo "API Gateway endpoint: https://${API_ID}.execute-api.${REGION}.amazonaws.com/prod/upload"