### EKS Logging node pool
module "eks-logging" {
  source = "../../../modules/eks-nodes/"

  basename = "${local.clusters.mgmt}-logging"
  pool     = "logging"

  cluster_name = local.clusters.mgmt
  cluster_sg   = module.mgmt-eks.sg

  aws_region       = var.aws_region
  vpc_id           = module.mgmt-vpc.id
  subnets          = module.devops-subnets.ids

  node_ami      = module.mgmt-eks.node_ami
  node_userdata = module.mgmt-eks.node_userdata

  node_instance_type = var.mgmt_logging_instance_type
  node_ebs_size      = var.mgmt_logging_ebs_size
  node_ssh_key       = var.ssh_bastion_key

  nodes_min = 4
  nodes_num = 4
  nodes_max = 4
}

### Logging Nodes Access
# Full access from bastion
resource "aws_security_group_rule" "bastion-eks-logging" {
  security_group_id = module.eks-logging.node_sg

  type       = "ingress"
  protocol   = "-1"
  from_port  = 0
  to_port    = 0

  source_security_group_id = aws_security_group.bastion.id
}

# Full access from master pool
resource "aws_security_group_rule" "master-eks-logging" {
  security_group_id = module.eks-logging.node_sg

  type       = "ingress"
  protocol   = "-1"
  from_port  = 0
  to_port    = 0

  source_security_group_id = module.eks-master.node_sg
}

### Outputs
output "logging_role_arn"  { value = module.eks-logging.node_role_arn }
output "logging_role_name" { value = module.eks-logging.node_role_name }

# vim:filetype=terraform ts=2 sw=2 et:
