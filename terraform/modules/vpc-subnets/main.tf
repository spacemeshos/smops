### Variables
variable "vpc_id"      { type = string }
variable "subnet_name" { type = string }
variable "subnet_cidr" { type = string }
variable "subnet_base" { default = 0 }
variable "subnet_bits" { default = 8 }
variable "subnet_azs"  { type = list(string) }
variable "extra_tags"  { default = {} }
variable "route_table" { type = string }

### Subnets: one per AZ
resource "aws_subnet" "subnets" {
  count = length(var.subnet_azs)

  vpc_id     = var.vpc_id
  cidr_block = cidrsubnet(var.subnet_cidr, var.subnet_bits, var.subnet_base + count.index)

  availability_zone = var.subnet_azs[count.index]

  # Add extra tags to subnets
  tags = merge(var.extra_tags, {
    Name = "${var.subnet_name}-${substr(var.subnet_azs[count.index], -1, 1)}"
  })
}

### Attach routing table to subnets if provided
resource "aws_route_table_association" "rt-assoc" {
  count = length(var.subnet_azs)

  subnet_id      = aws_subnet.subnets[count.index].id
  route_table_id = var.route_table
}

### Outputs
output "ids" { value = aws_subnet.subnets.*.id }

# vim:filetype=terraform ts=2 sw=2 et:
