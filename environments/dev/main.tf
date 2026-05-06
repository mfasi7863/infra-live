########################
# VPC Module
########################
module "vpc" {
  source = "git::https://github.com/mfasi7863/terraform-modules.git//vpc?ref=main"

  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
}

########################
# ECR Module
########################
module "ecr" {
  source    = "git::https://github.com/mfasi7863/terraform-modules.git//ecr?ref=main"
  repo_name = var.repo_name
}

########################
# EKS Module
########################
module "eks" {
  source = "git::https://github.com/mfasi7863/terraform-modules.git//eks?ref=main"

  cluster_name = var.cluster_name
  subnet_ids   = concat(module.vpc.public_subnets, module.vpc.private_subnets)

  depends_on = [module.vpc]
}
