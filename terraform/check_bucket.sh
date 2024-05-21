#!/bin/bash
BUCKET_NAME=$1
echo "Checking bucket: $BUCKET_NAME"
OUTPUT=$(aws s3api head-bucket --bucket $BUCKET_NAME 2>&1)
if [ $? -eq 0 ]; then
    echo "Bucket $BUCKET_NAME exists"
    echo "{\"exists\": true}"
    exit 0
else
    echo "Error: $OUTPUT"
    echo "{\"exists\": false}"
    exit 1
fi
