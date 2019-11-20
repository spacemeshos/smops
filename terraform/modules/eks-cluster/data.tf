### Data source: compatible AMI
data "aws_ami" "eks-node" {
  executable_users = ["all"]
  owners           = ["amazon"]
  most_recent      = true

  filter {
    name   = "name"
    values = ["amazon-eks-node-${aws_eks_cluster.eks.version}-v*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# vim:filetype=terraform ts=2 sw=2 et:
