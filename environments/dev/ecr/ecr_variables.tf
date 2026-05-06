variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "repo_name" {
  description = "ECR repository name"
  type        = string
  default     = "my-app"
}
