### General blurb
terraform {
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
  version = "~> 2.17"
}

provider "random" {
  version = "~> 2.1"
}

### Record the region as the output
output "region" { value = var.aws_region }

# vim:filetype=terraform ts=2 sw=2 et:
