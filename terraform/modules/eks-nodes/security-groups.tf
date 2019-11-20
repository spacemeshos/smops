### Security group for EKS nodes
resource "aws_security_group" "eks-node" {
  vpc_id = var.vpc_id
  name   = "${var.basename}-node"

  description = "Security Group for ${var.cluster_name} EKS Cluster Nodes"

  tags = {
    Name = "${var.basename}-node"
  }
}

# Allow any egress
resource "aws_security_group_rule" "eks-node-egress" {
  security_group_id = aws_security_group.eks-node.id

  type      = "egress"
  protocol  = "-1"
  from_port = 0
  to_port   = 0

  cidr_blocks      = ["0.0.0.0/0"]
  ipv6_cidr_blocks = ["::/0"]
}

# Allow any communication between nodes
resource "aws_security_group_rule" "eks-node-internal" {
  security_group_id = aws_security_group.eks-node.id

  type       = "ingress"
  protocol   = "-1"
  from_port  = 0
  to_port    = 0

  source_security_group_id = aws_security_group.eks-node.id
}

# Allow full access from control plane
resource "aws_security_group_rule" "eks-node-control" {
  security_group_id = aws_security_group.eks-node.id

  description = "Allow full access from k8s control plane"

  type       = "ingress"
  protocol   = "-1"
  from_port  = 0
  to_port    = 0

  source_security_group_id = var.cluster_sg
}

# Allow access from the nodes to control plane's API
resource "aws_security_group_rule" "eks-node-api" {
  security_group_id = var.cluster_sg

  description = "Allow access from EKS nodes to k8s API"

  type       = "ingress"
  protocol   = "tcp"
  from_port  = 443
  to_port    = 443

  source_security_group_id = aws_security_group.eks-node.id
}

# Allow access FROM security groups
resource "aws_security_group_rule" "eks-node-access-from-sgs" {
  count = length(var.access_from_sgs)

  security_group_id = aws_security_group.eks-node.id

  type       = "ingress"
  protocol   = "-1"
  from_port  = 0
  to_port    = 0

  source_security_group_id = var.access_from_sgs[count.index]
}

# Allow access TO security groups
resource "aws_security_group_rule" "eks-node-access-to-sgs" {
  count = length(var.access_to_sgs)

  security_group_id = var.access_to_sgs[count.index]

  type       = "ingress"
  protocol   = "-1"
  from_port  = 0
  to_port    = 0

  description = "Full access from ${var.basename} nodes"

  source_security_group_id = aws_security_group.eks-node.id
}

# vim:filetype=terraform ts=2 sw=2 et:
