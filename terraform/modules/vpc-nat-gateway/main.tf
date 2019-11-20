### Variables
variable "gw_name" { type = string }
variable "subnet_id" { type = string }
variable "route_tables" { type = list }

### Resources
# EIP
resource "aws_eip" "gw-eip" {
  vpc = true

  tags = {
    Name = var.gw_name
  }
}

# NAT Gateway
resource "aws_nat_gateway" "gw" {
  allocation_id = aws_eip.gw-eip.id
  subnet_id     = var.subnet_id

  tags = {
    Name = var.gw_name
  }
}

# Routes
resource "aws_route" "gw-routes" {
  count = length(var.route_tables)

  route_table_id         = var.route_tables[count.index]
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.gw.id
}

### Outputs
output "id"     { value = aws_nat_gateway.gw.id }
output "eip_id" { value = aws_eip.gw-eip.id }
output "eip"    { value = aws_eip.gw-eip.public_ip }

# vim:filetype=terraform ts=2 sw=2 et:
