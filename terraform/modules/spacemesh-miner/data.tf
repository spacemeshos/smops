# Availability zones
data "aws_availability_zones" "aws_azs" {}

### MGMT State
data "terraform_remote_state" "mgmt" {
  backend = "s3"
  config = {
    region  = "us-east-1"
    bucket  = "tfstate-us-east-1.spacemesh.io"
    key     = "environments/us-east-1/mgmt/terraform.tfstate"
  }
}

### InitFactory State
data "terraform_remote_state" "initfactory" {
  backend = "s3"
  config = {
    region  = "us-east-1"
    bucket  = "tfstate-us-east-1.spacemesh.io"
    key     = "environments/${var.aws_region}/initfactory/terraform.tfstate"
  }
}

### Handy locals
locals {
  eks_cluster_role = data.terraform_remote_state.mgmt.outputs.eks_cluster_role
  eks_admin_role   = data.terraform_remote_state.mgmt.outputs.eks_admin_role

  mgmt_vpc_id = data.terraform_remote_state.mgmt.outputs.mgmt_vpc_id

  mgmt_ops_rt = data.terraform_remote_state.mgmt.outputs.mgmt_pvt_rt
  mgmt_pub_rt = data.terraform_remote_state.mgmt.outputs.mgmt_pub_rt

  initdata_dynamodb_readwrite = data.terraform_remote_state.initfactory.outputs.initdata-dynamodb.policy_readwrite
  initdata_s3_readonly        = data.terraform_remote_state.initfactory.outputs.initdata-s3.policy_readonly
}

# vim:filetype=terraform ts=2 sw=2 et:
