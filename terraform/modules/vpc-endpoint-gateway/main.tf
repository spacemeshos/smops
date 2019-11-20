### Variables
variable "vpc_id" { type = string }
variable "name" { type = string }
variable "service_name" { type = string }
variable "route_tables" { type = list }

### Resources
# Endpoint
resource "aws_vpc_endpoint" "endpoint" {
  vpc_id          = var.vpc_id
  service_name    = var.service_name
  route_table_ids = var.route_tables
  auto_accept     = true

  tags = {
    Name = var.name
  }
}

### Outputs
output "id"             { value = aws_vpc_endpoint.endpoint.id }

# vim:filetype=terraform ts=2 sw=2 et:
