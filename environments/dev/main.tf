provider "aws" {
  region = "ap-south-1"
}

########################
# VPC Module
########################
module "vpc" {
  source       = "git::https://github.com/mfasi7863/terraform-modules.git//vpc?ref=main"
  cluster_name = "my-eks-cluster"
}

########################
# ECR Module
########################
module "ecr" {
  source    = "git::https://github.com/mfasi7863/terraform-modules.git//ecr?ref=main"
  repo_name = "my-app"
}

########################
# EKS Module
########################
module "eks" {
  source          = "git::https://github.com/mfasi7863/terraform-modules.git//eks?ref=main"
  cluster_name    = "my-eks-cluster"

  subnet_ids      = concat(module.vpc.public_subnets, module.vpc.private_subnets)
  node_subnet_ids = module.vpc.private_subnets

  depends_on = [module.vpc]
}
