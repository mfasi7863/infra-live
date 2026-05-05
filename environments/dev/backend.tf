terraform {
  backend "s3" {
    bucket       = "fasi-tf-state-bucket"
    key          = "dev/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
  }
}
