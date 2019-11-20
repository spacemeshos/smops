### InitFactory VPC
module "initfactory-vpc" {
  source = "../../../../../../modules/vpc/"
  
  vpc_name = "${local.basename}-initfactory-${var.aws_region}"
  vpc_cidr = var.initfactory_vpc_cidr
  vpc_azs  = data.aws_availability_zones.aws_azs.names

  # Tag the VPC as shared for the InitFactory cluster
  extra_tags = {
    "kubernetes.io/cluster/${local.clusters.initfactory}" = "shared"
  }
}

### InitFactory VPC Private route table
resource "aws_route_table" "initfactory-private" {
  vpc_id = module.initfactory-vpc.id

  tags = {
    Name = "${module.initfactory-vpc.name}-private"
  }
}

### InitFactory VPC NAT GW
# EIP
resource "aws_eip" "natgw-eip" {
  vpc = true

  tags = {
    Name = "${module.initfactory-vpc.name}-natgw"
  }
}

# Choose a random public subnet
resource "random_shuffle" "natgw-subnets" {
  input        = module.initfactory-vpc.public_subnets
  result_count = 1
}

# NAT Gateway
resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.natgw-eip.id
  subnet_id     = random_shuffle.natgw-subnets.result[0]

  tags = {
    Name = "${module.initfactory-vpc.name}-natgw"
  }
}

# Route
resource "aws_route" "gw-routes" {
  route_table_id         = aws_route_table.initfactory-private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.natgw.id
}

### Private subnets
module "private-subnets" {
  source = "../../../../../../modules/vpc-subnets/"

  vpc_id      = module.initfactory-vpc.id
  subnet_name = "${module.initfactory-vpc.name}-private"

  subnet_cidr = var.initfactory_vpc_cidr
  subnet_azs  = data.aws_availability_zones.aws_azs.names

  subnet_base = 10 

  # Private route table
  route_table = aws_route_table.initfactory-private.id

  # Tag the subnets as shared for the InitFactory cluster
  extra_tags = {
    "kubernetes.io/cluster/${local.clusters.initfactory}" = "shared"
  }
}

### InitFactory subnets
module "initfactory-subnets" {
  source = "../../../../../../modules/vpc-subnets/"

  vpc_id      = module.initfactory-vpc.id
  subnet_name = "${module.initfactory-vpc.name}-initfactory"

  subnet_cidr = var.initfactory_vpc_cidr
  subnet_azs  = data.aws_availability_zones.aws_azs.names

  # Use larger (e.g., 10.xx.16.0/20) subnets to allow more pods
  subnet_base = 1 
  subnet_bits = var.default_subnet_bits

  # Private route table
  route_table = aws_route_table.initfactory-private.id

  # Tag the subnets as shared for the InitFactory cluster
  extra_tags = {
    "kubernetes.io/cluster/${local.clusters.initfactory}" = "shared"
  }
}

### Outputs
output "initfactory_vpc" { value = module.initfactory-vpc.id } 

# vim:filetype=terraform ts=2 sw=2 et:
