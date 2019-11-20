### Variables
variable "name" { type = string }

variable "aws_region"   { type = string }
variable "admin_role"   { type = string }
variable "cluster_role" { type = string }

variable "vpc_id"  { type = string }
variable "subnets" { type = list(string) }

### Security group for EKS control plane
resource "aws_security_group" "eks" {
  vpc_id = var.vpc_id
  name   = "${var.name}-eks"

  description = "Security Group for ${var.name} EKS Cluster"

  tags = {
    Name   = "${var.name}-eks"
  }
}

# Allow any egress
resource "aws_security_group_rule" "eks-egress" {
  security_group_id = aws_security_group.eks.id

  type      = "egress"
  protocol  = "-1"
  from_port = 0
  to_port   = 0

  cidr_blocks      = ["0.0.0.0/0"]
  ipv6_cidr_blocks = ["::/0"]
}

### Provider to create the EKS
provider "aws" {
  alias = "admin"
  region = var.aws_region
  assume_role { role_arn = var.admin_role }
}

### EKS Cluster
resource "aws_eks_cluster" "eks" {
  provider = "aws.admin"

  name = var.name

  role_arn = var.cluster_role

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true

    subnet_ids = var.subnets

    security_group_ids = [aws_security_group.eks.id]
  }
}

# vim:filetype=terraform ts=2 sw=2 et:
