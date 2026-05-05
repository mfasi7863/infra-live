provider "aws" {
  region = "ap-south-1"
}

########################
# VPC Module
########################
module "vpc" {
  source       = "../../../terraform-modules/vpc"
  cluster_name = "my-eks-cluster"
}

########################
# ECR Module
########################
module "ecr" {
  source    = "../../../terraform-modules/ecr"
  repo_name = "my-app"
}

########################
# EKS Module
########################
module "eks" {
  source          = "../../../terraform-modules/eks"
  cluster_name    = "my-eks-cluster"

  subnet_ids      = concat(module.vpc.public_subnets, module.vpc.private_subnets)
  node_subnet_ids = module.vpc.private_subnets

  depends_on = [module.vpc]
}
