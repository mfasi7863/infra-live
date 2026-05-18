#!/bin/bash
set -euo pipefail

AWS_REGION="ap-south-1"
AWS_ACCOUNT_ID="672296383659"
SOURCE_IMAGE="fasiuddin007/kubeapp-frontend"
TARGET_REPOSITORY="terraform-aws-ecr"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Step 1: Get the git.sha tag from Docker Hub API
echo "Fetching latest git.sha tag from Docker Hub..."

# Fetch all tags for the image
TAGS_JSON=$(curl -s "https://hub.docker.com/v2/repositories/${SOURCE_IMAGE}/tags?page_size=10&ordering=last_updated")

# Extract the most recent tag that looks like a git sha (40-char hex)
GIT_SHA_TAG=$(echo "$TAGS_JSON" | \
  python3 -c "
import json, sys, re
data = json.load(sys.stdin)
tags = [t['name'] for t in data['results'] if re.fullmatch(r'[a-f0-9]{40}', t['name'])]
print(tags[0] if tags else '')
")

if [ -z "$GIT_SHA_TAG" ]; then
  echo "ERROR: No git sha tag found on Docker Hub. Exiting."
  exit 1
fi

echo "Found git sha tag: $GIT_SHA_TAG"

# Step 2: Login to ECR
echo "Logging into ECR..."
aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${ECR_REGISTRY}"

# Step 3: Pull the specific sha-tagged image
echo "Pulling image with tag: $GIT_SHA_TAG"
docker pull "${SOURCE_IMAGE}:${GIT_SHA_TAG}"

# Step 4: Tag it for ECR — both sha tag and latest
docker tag "${SOURCE_IMAGE}:${GIT_SHA_TAG}" "${ECR_REGISTRY}/${TARGET_REPOSITORY}:${GIT_SHA_TAG}"
docker tag "${SOURCE_IMAGE}:${GIT_SHA_TAG}" "${ECR_REGISTRY}/${TARGET_REPOSITORY}:latest"

# Step 5: Push both tags to ECR
echo "Pushing to ECR..."
docker push "${ECR_REGISTRY}/${TARGET_REPOSITORY}:${GIT_SHA_TAG}"
docker push "${ECR_REGISTRY}/${TARGET_REPOSITORY}:latest"

echo "Done! Pushed ${TARGET_REPOSITORY}:${GIT_SHA_TAG} and :latest to ECR"