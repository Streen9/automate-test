#!/bin/bash
BUCKET_NAME=$1
echo $BUCKET_NAME
OUTPUT=$(aws s3api head-bucket --bucket $BUCKET_NAME 2>&1)
if [ $? -eq 0 ]; then
    echo $BUCKET_NAME exists
    exit 0
else
    echo $OUTPUT
    exit 1
fi