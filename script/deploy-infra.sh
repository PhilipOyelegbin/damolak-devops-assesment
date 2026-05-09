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
    echo ">>> Deploying remote state..."
    cd "$PROJECT_ROOT/infra/remote-state"
    terraform init
    terraform validate
    terraform apply -auto-approve
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
