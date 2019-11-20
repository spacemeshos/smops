### Variables
variable "public_subnet_base" { default = 0 }
variable "public_subnet_bits" { default = 8 }

### Public route table
resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.vpc_name}-public"
  }
}

### Public Internet Gateway for public subnets
resource "aws_internet_gateway" "public-igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}
resource "aws_route" "public-rt-igw" {
  route_table_id         = aws_route_table.public-rt.id 
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.public-igw.id
}

### Public subnets
module "public-subnets" {
  source = "../vpc-subnets/"
  vpc_id = aws_vpc.vpc.id

  subnet_cidr = var.vpc_cidr
  subnet_base = var.public_subnet_base
  subnet_bits = var.public_subnet_bits
  subnet_name = "${var.vpc_name}-public"
  subnet_azs  = var.vpc_azs
  extra_tags  = var.extra_tags
  route_table = aws_route_table.public-rt.id
}


### Outputs
output "public_subnets" { value = module.public-subnets.ids }
output "public_rt"      { value = aws_route_table.public-rt.id }
output "public_igw"     { value = aws_internet_gateway.public-igw.id }

# vim:filetype=terraform ts=2 sw=2 et:
