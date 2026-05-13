#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="ap-south-1"
AWS_ACCOUNT_ID="672296383659"
SOURCE_IMAGE="fasiuddin007/kubeapp-frontend:latest"
TARGET_REPOSITORY="terraform-aws-ecr"
TARGET_IMAGE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${TARGET_REPOSITORY}:latest"

aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

docker pull "${SOURCE_IMAGE}"
docker tag "${SOURCE_IMAGE}" "${TARGET_IMAGE}"
docker push "${TARGET_IMAGE}"