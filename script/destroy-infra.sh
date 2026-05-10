#!/bin/bash

set -e

# Get the current script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [ "$1" != "staging" ] && [ "$1" != "production" ] && [ "$1" != "remote" ]; then
  echo "Usage: ./destroy-infra.sh [staging|production|remote]"
  exit 1
fi

if [ "$1" == "staging" ]; then
  echo ">>> Destroying staging infrastructure with Terraform..."
  cd "$PROJECT_ROOT/infra/environments/staging"
  terraform init
  terraform destroy -auto-approve
  echo ">>> Staging infrastructure destroyed successfully."
fi

if [ "$1" == "production" ]; then
  echo ">>> Destroying production infrastructure with Terraform..."
  cd "$PROJECT_ROOT/infra/environments/production"
  terraform init
  terraform destroy -auto-approve
  echo ">>> Production infrastructure destroyed successfully."
fi

if [ "$1" == "remote" ]; then
  echo ">>> Destroying remote state with AWS CLI..."
  aws s3 rm s3://damolak-assessment-remote-state --recursive
  aws s3 rb s3://damolak-assessment-remote-state --force
  echo ">>> Remote state destroyed successfully."
fi
