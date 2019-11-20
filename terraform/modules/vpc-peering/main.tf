### Inputs
variable "basename" { type = string }

variable "local_region"         { type = string }
variable "local_vpc_id"         { type = string }
variable "local_vpc_cidr"       { type = string }
variable "local_name"           { type = string }
variable "local_route_tables"   { type = list(string) }

variable "peer_region"         { type = string }
variable "peer_vpc_id"         { type = string }
variable "peer_vpc_cidr"       { type = string }
variable "peer_name"           { type = string }
variable "peer_route_tables"   { type = list(string) }

### VPC Peering Connection
resource "aws_vpc_peering_connection" "pcx" {
  vpc_id      = var.local_vpc_id
  peer_region = var.peer_region
  peer_vpc_id = var.peer_vpc_id

  tags = {
    Name = "${var.basename}-${var.local_name}-${var.peer_name}-${var.local_region}"
  }
}

### Accept VPC Peering
# Use peer region
provider "aws" {
  alias  = "peer"
  region = var.peer_region
}

resource "aws_vpc_peering_connection_accepter" "pcx" {
  provider                  = "aws.peer"
  vpc_peering_connection_id = aws_vpc_peering_connection.pcx.id
  auto_accept               = true

  tags = {
    Name = "${var.basename}-${var.local_name}-${var.peer_name}-${var.local_region}"
  }
}

### Allow mutual DNS resolution
resource "aws_vpc_peering_connection_options" "pcx-options" {
  count = 0 # FIXME: Doesn't work for now

  vpc_peering_connection_id = aws_vpc_peering_connection.pcx.id

  accepter {
    allow_remote_vpc_dns_resolution  = true
    allow_classic_link_to_remote_vpc = false
    allow_vpc_to_remote_classic_link = false
  }

  requester {
    allow_remote_vpc_dns_resolution  = true
    allow_classic_link_to_remote_vpc = false
    allow_vpc_to_remote_classic_link = false
  }

  depends_on = ["aws_vpc_peering_connection_accepter.pcx"]
}

### Local Routing tables rule
resource "aws_route" "local-pcx" {
  count = length(var.local_route_tables)

  route_table_id = var.local_route_tables[count.index]

  destination_cidr_block    = var.peer_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.pcx.id

  depends_on = ["aws_vpc_peering_connection_accepter.pcx"]
}

### Peer Routing tables rule
resource "aws_route" "peer-pcx" {
  provider = "aws.peer"

  count = length(var.peer_route_tables)

  route_table_id = var.peer_route_tables[count.index]

  destination_cidr_block    = var.local_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.pcx.id

  depends_on = ["aws_vpc_peering_connection_accepter.pcx"]
}

### Outputs
output "pcx_id" { value = aws_vpc_peering_connection.pcx.id }

# vim:filetype=terraform ts=2 sw=2 et:
