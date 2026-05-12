#!/usr/bin/env bash
set -euo pipefail

BASE_REF=${1:-origin/main}
HEAD_REF=${2:-HEAD}

CHANGED_FILES=$(git diff --name-only "$BASE_REF" "$HEAD_REF")

run_vpc=false
run_eks=false
run_ecr=false

while IFS= read -r file; do
  [[ -z "$file" ]] && continue

  case "$file" in
    environments/dev/vpc/*|terraform-modules/vpc/*)
      run_vpc=true
      ;;
    environments/dev/eks/*|terraform-modules/eks/*)
      run_eks=true
      ;;
    environments/dev/ecr/*|terraform-modules/ecr/*)
      run_ecr=true
      ;;
    .github/workflows/*|scripts/*)
      run_vpc=true
      run_eks=true
      run_ecr=true
      ;;
  esac
done <<< "$CHANGED_FILES"

{
  echo "run_vpc=$run_vpc"
  echo "run_eks=$run_eks"
  echo "run_ecr=$run_ecr"
} >> "$GITHUB_OUTPUT"