#!/bin/bash
BUCKET_NAME=$1
if aws s3api head-bucket --bucket $BUCKET_NAME 2>/dev/null; then
    echo $BUCKET_NAME exists
    exit 0
else
    echo $BUCKET_NAME does not exist
    exit 1
fi