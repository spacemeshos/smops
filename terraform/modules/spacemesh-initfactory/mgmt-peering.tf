### Peering to MGMT VPC
module "mgmt-peering" {
  source = "../../../../../../modules/vpc-peering/"

  basename = local.basename

  local_region       = var.aws_region
  local_vpc_id       = module.initfactory-vpc.id
  local_vpc_cidr     = var.initfactory_vpc_cidr
  local_name         = "initfactory"
  local_route_tables = [
    module.initfactory-vpc.default_rt,
    module.initfactory-vpc.public_rt,
    aws_route_table.initfactory-private.id,
  ]

  peer_name         = "mgmt"
  peer_region       = var.mgmt_region
  peer_vpc_id       = local.mgmt_vpc_id
  peer_vpc_cidr     = var.mgmt_vpc_cidr
  peer_route_tables = [
    local.mgmt_ops_rt,
    local.mgmt_pub_rt,
  ]
}

# vim:filetype=terraform ts=2 sw=2 et:
