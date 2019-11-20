### Miner EKS
# Choose two random subnets of all the available public ones
resource "random_shuffle" "eks-subnets" {
  input        = module.miner-vpc.public_subnets
  result_count = 2
}

# Create EKS cluster in the chosen subnets
module "miner-eks" {
  source = "../../../../../../modules/eks-cluster/"

  name = local.clusters.miner

  aws_region = var.aws_region
  vpc_id     = module.miner-vpc.id
  subnets    = random_shuffle.eks-subnets.result

  cluster_role = local.eks_cluster_role
  admin_role   = local.eks_admin_role
}

# Allow access to EKS master from MGMT VPC
resource "aws_security_group_rule" "eks-mgmt" {
  security_group_id = module.miner-eks.sg

  type       = "ingress"
  protocol   = "-1"
  from_port  = 0
  to_port    = 0

  cidr_blocks = [var.mgmt_vpc_cidr]
}

### Outputs
output "eks-miner" {
  value = {
    endpoint = module.miner-eks.endpoint
    cadata   = module.miner-eks.ca_data
  }
}

# vim:filetype=terraform ts=2 sw=2 et:
