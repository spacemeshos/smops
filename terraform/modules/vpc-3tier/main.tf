###
### 3-Tier VPC: VPC, Public subnets, Public/Private/Default route table(s)
###

### Inputs
variable "vpc_cidr" { type = string }
variable "vpc_name" { type = string }
variable "vpc_azs"  { type = list }

variable "public_subnet_base" { default = 0 }
variable "public_subnet_bits" { default = 8 }

variable "extra_tags" { default = {} }

### VPC + Public Subnets + Public Route Table
module "vpc" {
  source = "../vpc/"

  vpc_name = var.vpc_name
  vpc_cidr = var.vpc_cidr
  vpc_azs  = var.vpc_azs

  public_subnet_base = var.public_subnet_base
  public_subnet_bits = var.public_subnet_bits

  extra_tags = var.extra_tags
}

### NATGW + Private Route Table
# EIP
resource "aws_eip" "natgw-eip" {
  vpc = true

  tags = {
    Name = "${var.vpc_name}-natgw"
  }
}

# Choose a random public subnet ...
resource "random_shuffle" "natgw-subnets" {
  input        = module.vpc.public_subnets
  result_count = 1
}

# ... and put a NAT Gateway there
resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.natgw-eip.id
  subnet_id     = random_shuffle.natgw-subnets.result[0]

  tags = {
    Name = "${var.vpc_name}-natgw"
  }
}

# Route Table
resource "aws_route_table" "private" {
  vpc_id = module.vpc.id

  tags = {
    Name = "${var.vpc_name}-private"
  }
}

# Route
resource "aws_route" "natgw-route" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.natgw.id
}

### Outputs
output "id"         { value = module.vpc.id }
output "name"       { value = var.vpc_name }

output "public_subnets" { value = module.vpc.public_subnets }
output "public_rt"      { value = module.vpc.public_rt }
output "public_igw"     { value = module.vpc.public_igw }

output "default_rt" { value = module.vpc.default_rt }
output "default_sg" { value = module.vpc.default_sg }

output "private_rt"    { value = aws_route_table.private.id }
output "private_natgw" { value = aws_nat_gateway.natgw.id }

# vim:filetype=terraform ts=2 sw=2 et:
