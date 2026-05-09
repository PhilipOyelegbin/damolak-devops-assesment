#!/bin/bash

set -e

# Get the directory of the script and the project root
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

if [ "$1" != "staging" ] && [ "$1" != "production" ] && [ "$1" != "remote" ]; then
  echo "Usage: ./deploy-infra.sh [staging|production|remote]"
  exit 1
fi

if [ "$1" == "remote" ]; then
    echo ">>> Deploying remote state with AWS CLI..."
    aws s3api create-bucket \
        --bucket damolak-assessment-remote-state \
        --region eu-west-2 \
        --create-bucket-configuration LocationConstraint=eu-west-2

    aws s3api put-public-access-block \
        --bucket damolak-assessment-remote-state \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

    aws s3api put-bucket-encryption \
        --bucket damolak-assessment-remote-state \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }
            ]
        }'
    echo ">>> Remote state deployed successfully."
fi

if [ "$1" == "staging" ]; then
    echo ">>> Deploying staging infrastructure with Terraform..."
    cd "$PROJECT_ROOT/infra/environments/staging"
    terraform init
    terraform validate
    terraform apply -auto-approve
    echo ">>> Staging infrastructure deployed successfully."
fi

if [ "$1" == "production" ]; then
    echo ">>> Deploying production infrastructure with Terraform..."
    cd "$PROJECT_ROOT/infra/environments/production"
    terraform init
    terraform validate
    terraform apply -auto-approve
    echo ">>> Production infrastructure deployed successfully."
fi
