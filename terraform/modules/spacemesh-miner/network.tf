### Miner VPC
module "miner-vpc" {
  source = "../../../../../../modules/vpc/"
  
  vpc_name = "${local.basename}-miner-${var.aws_region}"
  vpc_cidr = var.miner_vpc_cidr
  vpc_azs  = data.aws_availability_zones.aws_azs.names

  public_subnet_bits = var.default_subnet_bits

  # Tag the VPC as shared for the InitFactory cluster
  extra_tags = {
    "kubernetes.io/cluster/${local.clusters.miner}" = "shared"
  }
}

### Miner VPC Flow Log
resource "aws_flow_log" "main" {
  vpc_id       = module.miner-vpc.id
  traffic_type = "ALL"

  log_destination_type = "s3"
  log_destination = "arn:aws:s3:::${local.mgmt_logs_bucket}"
}

### Miner VPC Private route table
resource "aws_route_table" "miner-private" {
  vpc_id = module.miner-vpc.id

  tags = {
    Name = "${module.miner-vpc.name}-private"
  }
}

### Miner VPC NAT GW
# EIP
resource "aws_eip" "natgw-eip" {
  vpc = true

  tags = {
    Name = "${module.miner-vpc.name}-natgw"
  }
}

# Choose a random public subnet
resource "random_shuffle" "natgw-subnets" {
  input        = module.miner-vpc.public_subnets
  result_count = 1
}

# NAT Gateway
resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.natgw-eip.id
  subnet_id     = random_shuffle.natgw-subnets.result[0]

  tags = {
    Name = "${module.miner-vpc.name}-natgw"
  }
}

# Route
resource "aws_route" "gw-routes" {
  route_table_id         = aws_route_table.miner-private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.natgw.id
}

### Private subnets
module "private-subnets" {
  source = "../../../../../../modules/vpc-subnets/"

  vpc_id      = module.miner-vpc.id
  subnet_name = "${module.miner-vpc.name}-private"

  subnet_cidr = var.miner_vpc_cidr
  subnet_azs  = data.aws_availability_zones.aws_azs.names

  subnet_base = var.miner_pvt_subnet_base 

  # Private route table
  route_table = aws_route_table.miner-private.id

  # Tag the subnets as shared for the InitFactory cluster
  extra_tags = {
    "kubernetes.io/cluster/${local.clusters.miner}" = "shared"
  }
}

### Outputs
output "miner_vpc"         { value = module.miner-vpc.id }
output "miner_vpc_flowlog" { value = aws_flow_log.main.id }

# vim:filetype=terraform ts=2 sw=2 et:
