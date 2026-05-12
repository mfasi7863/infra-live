terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "terraform-aws-project"
      Environment = var.environment
      ManagedBy   = "terraform"
      Component   = "ecr"
    }
  }
}