module "vpc" {
  source = "git::https://github.com/mfasi7863/terraform-modules.git//vpc"

  aws_region           = var.aws_region
  environment          = var.environment
  vpc_name             = var.vpc_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}# updated
