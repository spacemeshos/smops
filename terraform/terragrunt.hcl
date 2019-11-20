inputs = {
  aws_region     = local.aws_region
  project_env    = ""
  project_name   = local.project_name
  project_domain = local.project_domain
}

locals {
  aws_region     = "us-east-1"
  project_name   = "spacemesh"
  project_domain = "spacemesh.io"
}

terraform {
  extra_arguments "custom_vars" {
    commands = get_terraform_commands_that_need_vars()

    required_var_files = [
      "${get_parent_terragrunt_dir()}/common.tfvars",
    ]

    optional_var_files = [
      "${get_terragrunt_dir()}/../common.tfvars",
    ]
  }
}

remote_state {
  backend = "s3"
  config = {
    region  = "us-east-1"
    bucket  = "tfstate-us-east-1.spacemesh.io"
    key     = "${path_relative_to_include()}/terraform.tfstate"
    encrypt = true

    dynamodb_table = lower("${local.project_name}-tfstate-locks.${local.aws_region}.${local.project_domain}")
  }
}

# vim:filetype=terraform ts=2 sw=2 et:
