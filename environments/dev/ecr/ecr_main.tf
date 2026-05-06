module "ecr" {
  source = "git::https://github.com/mfasi7863/terraform-modules.git//ecr?ref=main"

  repo_name = var.repo_name
}
