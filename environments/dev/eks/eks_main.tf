data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = "vpc/terraform.tfstate"
    region = var.state_region
  }
}

module "eks" {
  source = "git::https://github.com/mfasi7863/terraform-modules.git//eks?ref=main"

  cluster_name = var.cluster_name
  cluster_tags = {
    "alpha.eksctl.io/cluster-oidc-enabled" = "true"
  }
  subnet_ids = concat(
    data.terraform_remote_state.vpc.outputs.public_subnets,
    data.terraform_remote_state.vpc.outputs.private_subnets
  )
  node_subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnets
}
