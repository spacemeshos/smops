### MGMT EKS
# Choose two random subnets of all the available public ones
resource "random_shuffle" "mgmt-eks-subnets" {
  input        = module.mgmt-vpc.public_subnets
  result_count = 2
}

# Create EKS cluster in the chosen subnets
module "mgmt-eks" {
  source = "../../../modules/eks-cluster/"

  name = local.clusters.mgmt

  aws_region = var.aws_region
  vpc_id     = module.mgmt-vpc.id
  subnets    = random_shuffle.mgmt-eks-subnets.result


  cluster_role = module.eks-roles.cluster_role_arn
  admin_role   = module.eks-roles.admin_role_arn
}

### Allow access from bastion
resource "aws_security_group_rule" "mgmt-eks-bastion" {
  security_group_id = module.mgmt-eks.sg

  description = "Full access from bastion"

  type       = "ingress"
  protocol   = "-1"
  from_port  = 0
  to_port    = 0

  source_security_group_id = aws_security_group.bastion.id
}

### Outputs
output "eks-mgmt" {
  value = {
    endpoint = module.mgmt-eks.endpoint
    cadata   = module.mgmt-eks.ca_data
  }
}

# vim:filetype=terraform ts=2 sw=2 et:
