variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "my-eks-cluster"
}

variable "state_bucket" {
  description = "S3 bucket that stores Terraform remote state"
  type        = string
  default     = "fasi-tf-state-bucket"
}

variable "state_region" {
  description = "AWS region for the Terraform state bucket"
  type        = string
  default     = "ap-south-1"
}
