data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket       = var.vpc_state_bucket
    key          = var.vpc_state_key
    region       = var.aws_region
    use_lockfile = true
  }
}

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