### Variables
variable "vpc_cidr" { type = string }
variable "vpc_name" { type = string }
variable "vpc_azs"  { type = list }

variable "extra_tags" { default = {} }

### VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = merge(var.extra_tags, {
    Name = var.vpc_name
  })
}

### Outputs
output "id"         { value = aws_vpc.vpc.id }
output "name"       { value = var.vpc_name }
output "default_rt" { value = aws_vpc.vpc.default_route_table_id }
output "default_sg" { value = aws_vpc.vpc.default_security_group_id }

# vim:filetype=terraform ts=2 sw=2 et:
