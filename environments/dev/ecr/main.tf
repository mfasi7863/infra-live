module "ecr" {
  source = "git::https://github.com/mfasi7863/terraform-modules.git//ecr"

  aws_region           = var.aws_region
  environment          = var.environment
  repository_name      = var.repository_name
  image_tag_mutability = var.image_tag_mutability
}