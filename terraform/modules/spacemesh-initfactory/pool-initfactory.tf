### EKS InitFactory node pool
module "eks-initfactory" {
  source = "../../../../../../modules/eks-nodes/"

  basename = "${local.clusters.initfactory}-initfactory"

  pool = "initfactory"

  cluster_name = local.clusters.initfactory
  cluster_sg   = module.initfactory-eks.sg

  aws_region         = var.aws_region
  vpc_id             = module.initfactory-vpc.id
  subnets            = module.initfactory-subnets.ids
  placement_strategy = "cluster"

  node_ami      = module.initfactory-eks.node_ami
  node_userdata = module.initfactory-eks.node_userdata

  node_instance_type = var.initfactory_node_instance_type
  node_ebs_size      = var.initfactory_node_ebs_size
  node_ssh_key       = var.ssh_bastion_key

  nodes_min = var.initfactory_nodes_min
  nodes_num = var.initfactory_nodes_num
  nodes_max = var.initfactory_nodes_max
}

### InitFactory Nodes: Access from MGMT
resource "aws_security_group_rule" "eks-initfactory-mgmt" {
  security_group_id = module.eks-initfactory.node_sg

  type       = "ingress"
  protocol   = "-1"
  from_port  = 0
  to_port    = 0

  cidr_blocks = [var.mgmt_vpc_cidr]
}

### InitFactory Nodes: Access from Master nodes
resource "aws_security_group_rule" "eks-initfactory-master" {
  security_group_id = module.eks-initfactory.node_sg

  type       = "ingress"
  protocol   = "-1"
  from_port  = 0
  to_port    = 0

  source_security_group_id = module.eks-master.node_sg
}

### Allow master to resize InitFactory pool
resource "aws_iam_role_policy_attachment" "eks-master-initfactory-resize" {
  role = module.eks-master.node_role_name
  policy_arn = module.eks-initfactory.policy_resize
}

### Outputs
output "initfactory_role_arn"  { value = module.eks-initfactory.node_role_arn }
output "initfactory_role_name" { value = module.eks-initfactory.node_role_name }

output "initfactory_asg" { value = module.eks-initfactory.node_scaling_group }

# vim:filetype=terraform ts=2 sw=2 et:
