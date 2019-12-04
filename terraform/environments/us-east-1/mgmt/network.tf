### MGMT VPC + Public Subnets + Public/Private Route Tables
module "mgmt-vpc" {
  source = "../../../modules/vpc-3tier/"

  vpc_name = "${local.basename}-mgmt-${var.aws_region}"
  vpc_cidr = var.mgmt_vpc_cidr
  vpc_azs  = data.aws_availability_zones.aws_azs.names

  # Tag the VPC as shared for the MGMT cluster
  extra_tags = {
    "kubernetes.io/cluster/${local.clusters.mgmt}" = "shared"
  }
}

### MGMT VPC Flow Log
resource "aws_flow_log" "main" {
  vpc_id       = module.mgmt-vpc.id
  traffic_type = "ALL"

  log_destination_type = "s3"
  log_destination = "arn:aws:s3:::${module.cloudtrail.bucket}"
}

### DevOPS Subnets
module "devops-subnets" {
  source = "../../../modules/vpc-subnets/"

  vpc_id      = module.mgmt-vpc.id
  subnet_cidr = var.mgmt_vpc_cidr
  subnet_azs  = data.aws_availability_zones.aws_azs.names
  subnet_base = 10
  subnet_bits = 8
  subnet_name = "${module.mgmt-vpc.name}-devops"
  route_table = module.mgmt-vpc.private_rt

  # Tag the subnets as shared for the MGMT cluster
  extra_tags = {
    "kubernetes.io/cluster/${local.clusters.mgmt}" = "shared"
  }
}

### PoET Subnets
module "poet-subnets" {
  source = "../../../modules/vpc-subnets/"

  vpc_id      = module.mgmt-vpc.id
  subnet_cidr = var.mgmt_vpc_cidr
  subnet_azs  = data.aws_availability_zones.aws_azs.names
  subnet_base = 20
  subnet_bits = 8
  subnet_name = "${module.mgmt-vpc.name}-poet"
  route_table = module.mgmt-vpc.private_rt

  # Tag the subnets as shared for the MGMT cluster
  extra_tags = {
    "kubernetes.io/cluster/${local.clusters.mgmt}" = "shared"
  }
}

### Outputs
output "mgmt_vpc_id"      { value = module.mgmt-vpc.id }
output "mgmt_vpc_flowlog" { value = aws_flow_log.main.id }
output "mgmt_pub_rt"      { value = module.mgmt-vpc.public_rt }
output "mgmt_pvt_rt"      { value = module.mgmt-vpc.private_rt }

# vim:filetype=terraform ts=2 sw=2 et:
