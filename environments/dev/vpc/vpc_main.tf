module "vpc" {
  source = "git::https://github.com/mfasi7863/terraform-modules.git//vpc?ref=main"

  cluster_name    = var.cluster_name
  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "igw_id" {
  value = module.vpc.igw_id
}

output "nat_gateway_id" {
  value = module.vpc.nat_gateway_id
}
