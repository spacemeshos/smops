### InitFactory EKS
# Choose two random subnets of all the available public ones
resource "random_shuffle" "initfactory-eks-subnets" {
  input        = module.initfactory-vpc.public_subnets
  result_count = 2
}

# Create EKS cluster in the chosen subnets
module "initfactory-eks" {
  source = "../../../../../../modules/eks-cluster/"

  name = local.clusters.initfactory

  aws_region = var.aws_region
  vpc_id     = module.initfactory-vpc.id
  subnets    = random_shuffle.initfactory-eks-subnets.result


  cluster_role = local.eks_cluster_role
  admin_role   = local.eks_admin_role
}

# Allow access to EKS master from MGMT VPC
resource "aws_security_group_rule" "eks-mgmt" {
  security_group_id = module.initfactory-eks.sg

  type       = "ingress"
  protocol   = "-1"
  from_port  = 0
  to_port    = 0

  cidr_blocks = [var.mgmt_vpc_cidr]
}

### Outputs
output "eks-initfactory" {
  value = {
    endpoint = module.initfactory-eks.endpoint
    cadata   = module.initfactory-eks.ca_data
  }
}

# vim:filetype=terraform ts=2 sw=2 et:
