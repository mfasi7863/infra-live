# infra-live

Live Terraform infrastructure for the AWS EKS GitOps project.

This repository contains the environment-specific Terraform roots and GitHub Actions workflows used to provision and update the AWS infrastructure for the project. Reusable infrastructure logic lives in the separate `terraform-modules` repository, while Kubernetes application delivery lives in the separate `app-config` repository.

## What This Repository Manages

`infra-live` manages the `dev` AWS environment in `ap-south-1`:

- VPC networking
- Public and private subnets
- Internet Gateway and NAT Gateway routing
- Amazon ECR repository for application images
- Amazon EKS cluster
- EKS managed node group
- Terraform remote state in S3

The infrastructure is intentionally split into independent component roots so each stack has its own state file and can be planned or applied separately.

## Architecture

```text
infra-live
  |
  |-- uses modules from terraform-modules
  |
  |-- authenticates to Vault through GitHub Actions OIDC/JWT
  |
  |-- receives temporary AWS credentials from Vault
  |
  |-- provisions AWS infrastructure with Terraform
  |
  +-- stores Terraform state in S3
```

High-level flow:

```text
Pull request or push to main
        |
        v
infra-plan workflow
        |
        v
Detect changed components
        |
        v
Get temporary AWS credentials from Vault
        |
        v
terraform init, validate, plan
        |
        v
Upload tfplan artifact
        |
        v
Manual infra-apply workflow
        |
        v
Download latest successful plan artifact
        |
        v
terraform apply
```

## Repository Structure

```text
.
|-- .github/
|   +-- workflows/
|       |-- infra-plan.yml
|       |-- infra-apply.yml
|       +-- test.yml
|-- environments/
|   +-- dev/
|       |-- vpc/
|       |   |-- backend.tf
|       |   |-- main.tf
|       |   |-- outputs.tf
|       |   |-- providers.tf
|       |   |-- terraform.tfvars
|       |   +-- variables.tf
|       |-- ecr/
|       |   |-- backend.tf
|       |   |-- main.tf
|       |   |-- outputs.tf
|       |   |-- providers.tf
|       |   |-- terraform.tfvars
|       |   +-- variables.tf
|       +-- eks/
|           |-- backend.tf
|           |-- main.tf
|           |-- outputs.tf
|           |-- providers.tf
|           |-- terraform.tfvars
|           +-- variables.tf
|-- scripts/
|   |-- changed-components.sh
|   +-- migrate-dockerhub-to-ecr.sh
+-- README.md
```

## Components

### VPC

Path:

```text
environments/dev/vpc
```

The VPC component creates the base network used by EKS:

- VPC CIDR: `10.0.0.0/16`
- Public subnets:
  - `10.0.1.0/24`
  - `10.0.2.0/24`
- Private subnets:
  - `10.0.11.0/24`
  - `10.0.12.0/24`
- Availability zones:
  - `ap-south-1a`
  - `ap-south-1b`
- Internet Gateway
- NAT Gateway
- Public and private route tables

The VPC root calls:

```hcl
module "vpc" {
  source = "git::https://github.com/mfasi7863/terraform-modules.git//vpc"

  aws_region           = var.aws_region
  environment          = var.environment
  vpc_name             = var.vpc_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}
```

Outputs from this component are consumed by the EKS component through Terraform remote state.

### ECR

Path:

```text
environments/dev/ecr
```

The ECR component creates the private container repository used by the application pipeline:

- Repository name: `terraform-aws-ecr`
- Region: `ap-south-1`
- Image tag mutability: `MUTABLE`
- Image scanning on push: enabled in the module

The ECR root calls:

```hcl
module "ecr" {
  source = "git::https://github.com/mfasi7863/terraform-modules.git//ecr"

  aws_region           = var.aws_region
  environment          = var.environment
  repository_name      = var.repository_name
  image_tag_mutability = var.image_tag_mutability
}
```

### EKS

Path:

```text
environments/dev/eks
```

The EKS component creates the Kubernetes control plane and managed worker node group:

- Cluster name: `dev-eks-cluster`
- Kubernetes version: `1.30`
- Node group: `dev-general`
- Instance type: `t3.medium`
- Desired size: `2`
- Minimum size: `1`
- Maximum size: `3`

The EKS root reads the VPC state from S3:

```hcl
data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket       = var.vpc_state_bucket
    key          = var.vpc_state_key
    region       = var.aws_region
    use_lockfile = true
  }
}
```

Then it passes the VPC outputs into the EKS module:

```hcl
module "eks" {
  source = "git::https://github.com/mfasi7863/terraform-modules.git//eks"

  aws_region      = var.aws_region
  environment     = var.environment
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids      = data.terraform_remote_state.vpc.outputs.private_subnet_ids
  node_group_name = var.node_group_name
  instance_types  = var.instance_types
  desired_size    = var.desired_size
  min_size        = var.min_size
  max_size        = var.max_size
}
```

## Terraform State

Terraform state is stored in Amazon S3.

| Component | State object |
|---|---|
| VPC | `dev/vpc/terraform.tfstate` |
| ECR | `dev/ecr/terraform.tfstate` |
| EKS | `dev/eks/terraform.tfstate` |

Backend settings:

```text
Bucket: terraform-state-devops-ap-south-1
Region: ap-south-1
Locking: S3 native lock file
```

Each component has an empty backend block:

```hcl
terraform {
  required_version = ">= 1.10.0"

  backend "s3" {}
}
```

The actual backend values are supplied during `terraform init` by GitHub Actions:

```bash
terraform init \
  -backend-config="bucket=terraform-state-devops-ap-south-1" \
  -backend-config="key=dev/<component>/terraform.tfstate" \
  -backend-config="region=ap-south-1" \
  -backend-config="use_lockfile=true"
```

Terraform `use_lockfile=true` requires Terraform 1.10 or newer. This repo uses Terraform `1.10.5` in GitHub Actions.

## Vault Authentication

GitHub Actions does not use static AWS access keys.

Instead, workflows use this pattern:

1. GitHub Actions requests an OIDC/JWT token.
2. The workflow authenticates to Vault with `hashicorp/vault-action@v3`.
3. Vault validates the repository claims against the `github-terraform` role.
4. Vault returns short-lived AWS credentials from `aws/creds/terraform-role`.
5. Terraform uses those temporary credentials for plan or apply.

Workflow credential mapping:

```yaml
secrets: |
  aws/creds/terraform-role access_key     | AWS_ACCESS_KEY_ID ;
  aws/creds/terraform-role secret_key     | AWS_SECRET_ACCESS_KEY ;
  aws/creds/terraform-role security_token | AWS_SESSION_TOKEN
```

The GitHub repository must contain the secret:

```text
VAULT_ADDR
```

`VAULT_ADDR` should point to the reachable Vault API endpoint.

## GitHub Actions Workflows

### `infra-plan.yml`

Runs automatically on:

- Pull requests targeting `main`
- Pushes to `main`

What it does:

1. Checks which component folders changed.
2. Runs Terraform only for changed components.
3. Authenticates to Vault.
4. Installs Terraform `1.10.5`.
5. Runs `terraform init`.
6. Runs `terraform validate`.
7. Runs `terraform plan -out=tfplan`.
8. Uploads the generated plan as an artifact.

Artifact names:

```text
vpc-tfplan
ecr-tfplan
eks-tfplan
```

### `infra-apply.yml`

Runs manually with `workflow_dispatch`.

What it does:

1. Finds the latest successful `infra-plan` workflow run.
2. Checks which plan artifacts exist.
3. Downloads the relevant plan artifacts from that workflow run.
4. Authenticates to Vault.
5. Runs `terraform init`.
6. Runs `terraform apply -auto-approve tfplan`.

Apply order:

```text
VPC -> ECR -> EKS
```

This order matters because EKS depends on VPC remote state.

## Change Detection

Change detection is handled by:

```text
scripts/changed-components.sh
```

The script compares two Git refs and sets GitHub Actions outputs:

```text
run_vpc=true|false
run_eks=true|false
run_ecr=true|false
```

Rules:

- Changes under `environments/dev/vpc/*` run VPC.
- Changes under `environments/dev/eks/*` run EKS.
- Changes under `environments/dev/ecr/*` run ECR.
- Changes under `.github/workflows/*` or `scripts/*` run all components.

## DockerHub to ECR Migration Script

The helper script:

```text
scripts/migrate-dockerhub-to-ecr.sh
```

Migrates the latest Git SHA tagged image from Docker Hub to ECR.

Source image:

```text
fasiuddin007/kubeapp-frontend
```

Target image:

```text
672296383659.dkr.ecr.ap-south-1.amazonaws.com/terraform-aws-ecr
```

The script:

1. Reads Docker Hub tags.
2. Finds the newest 40-character Git SHA tag.
3. Logs into ECR.
4. Pulls the Docker Hub image.
5. Tags it for ECR with both the SHA tag and `latest`.
6. Pushes both tags to ECR.

Run it from the repository root:

```bash
chmod +x scripts/migrate-dockerhub-to-ecr.sh
./scripts/migrate-dockerhub-to-ecr.sh
```

The machine running the script must have Docker and AWS credentials that can push to ECR.

## Local Usage

GitHub Actions is the preferred execution path because it uses Vault-issued temporary AWS credentials. For local testing, export valid AWS credentials first.

Example local plan for VPC:

```bash
cd environments/dev/vpc

terraform init \
  -backend-config="bucket=terraform-state-devops-ap-south-1" \
  -backend-config="key=dev/vpc/terraform.tfstate" \
  -backend-config="region=ap-south-1" \
  -backend-config="use_lockfile=true"

terraform validate
terraform plan
```

Example local plan for ECR:

```bash
cd environments/dev/ecr

terraform init \
  -backend-config="bucket=terraform-state-devops-ap-south-1" \
  -backend-config="key=dev/ecr/terraform.tfstate" \
  -backend-config="region=ap-south-1" \
  -backend-config="use_lockfile=true"

terraform validate
terraform plan
```

Example local plan for EKS:

```bash
cd environments/dev/eks

terraform init \
  -backend-config="bucket=terraform-state-devops-ap-south-1" \
  -backend-config="key=dev/eks/terraform.tfstate" \
  -backend-config="region=ap-south-1" \
  -backend-config="use_lockfile=true"

terraform validate
terraform plan
```

## Deployment Order

For a fresh environment, create infrastructure in this order:

1. VPC
2. ECR
3. EKS
4. Install Argo CD on EKS
5. Apply Argo CD project and application manifests from `app-config`
6. Build or migrate the application image into ECR
7. Let Argo CD sync the application

EKS should not be applied before VPC state exists, because it reads VPC outputs from:

```text
dev/vpc/terraform.tfstate
```

## Useful Commands

Check AWS identity:

```bash
aws sts get-caller-identity
```

Update kubeconfig after EKS is created:

```bash
aws eks update-kubeconfig --region ap-south-1 --name dev-eks-cluster
```

Check EKS nodes:

```bash
kubectl get nodes
```

Check Argo CD:

```bash
kubectl get pods -n argocd
kubectl get applications -n argocd
```

Check the application:

```bash
kubectl get all -n terraform-aws-ecr
```

## Troubleshooting Notes

### `No stored state was found`

This usually means EKS is trying to read VPC remote state before VPC has been applied.

Fix:

```text
Apply VPC first, then run EKS plan/apply.
```

### `InvalidClientTokenId`

This can happen if Vault returns invalid or incomplete AWS credentials.

Fix:

- Use Vault AWS secrets engine with `credential_type=assumed_role`.
- Export `AWS_SESSION_TOKEN` along with access key and secret key.

### `invalid subject (sub) claim`

Vault rejected the GitHub Actions JWT because the repo or branch claim did not match the Vault role.

Fix:

- Check the Vault JWT role.
- Use `bound_claims_type=glob`.
- Match the repo pattern, for example `repo:mfasi7863/infra-live:*`.

### EKS `kubectl` authentication failure

If `aws eks update-kubeconfig` works but `kubectl get nodes` fails, the IAM role may not be authorized in the cluster.

Fix:

- Enable EKS access entries with `API_AND_CONFIG_MAP`.
- Create an access entry for the admin role.
- Associate `AmazonEKSClusterAdminPolicy`.

## Related Repositories

- `terraform-modules`: reusable Terraform modules used by this repo.
- `app-config`: Argo CD project, application, and Helm chart configuration.
- `k8s`: application code, Dockerfile, and image build/push workflow.

## Security Notes

- Do not commit AWS access keys.
- Do not commit Vault root tokens or unseal keys.
- Use GitHub OIDC/JWT with Vault instead of static cloud credentials.
- Keep `infra-apply` protected with a GitHub environment approval.
- Rotate any credentials used during initial Vault bootstrap.
- Use least-privilege IAM policies for production hardening.

## Cleanup

Destroy infrastructure in reverse dependency order:

1. Application workloads and LoadBalancers
2. Argo CD resources
3. EKS
4. ECR
5. VPC

Do not destroy the VPC first. EKS and LoadBalancer resources can leave ENIs and security groups behind, which will block VPC deletion.
