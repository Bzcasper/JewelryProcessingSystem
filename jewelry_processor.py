# jewelry_processor.py
import boto3
import json
import os
import cloudinary
import cloudinary.uploader

# Initialize clients
s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('jewelry-metadata')

# Configure Cloudinary
cloudinary.config(
    cloud_name = os.environ['CLOUDINARY_CLOUD_NAME'],
    api_key = os.environ['CLOUDINARY_API_KEY'],
    api_secret = os.environ['CLOUDINARY_API_SECRET']
)

def handler(event, context):
    # Get bucket and key from event
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    
    try:
        # Download image from S3
        local_path = f"/tmp/{key}"
        s3.download_file(bucket, key, local_path)
        
        # Upload to Cloudinary
        result = cloudinary.uploader.upload(local_path)
        
        # Store metadata in DynamoDB
        table.put_item(
            Item={
                'imageId': key,
                'cloudinaryUrl': result['secure_url'],
                'metadata': {
                    'format': result['format'],
                    'size': result['bytes'],
                    'dimensions': {
                        'width': result['width'],
                        'height': result['height']
                    }
                }
            }
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Image processed successfully',
                'imageUrl': result['secure_url']
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }