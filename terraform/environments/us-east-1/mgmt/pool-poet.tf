### EKS PoET node pool
module "eks-poet" {
  source = "../../../modules/eks-nodes/"

  basename = "${local.clusters.mgmt}-poet"

  pool = "poet"

  cluster_name = local.clusters.mgmt
  cluster_sg   = module.mgmt-eks.sg

  aws_region       = var.aws_region
  vpc_id           = module.mgmt-vpc.id
  subnets          = module.poet-subnets.ids

  node_ami      = module.mgmt-eks.node_ami
  node_userdata = module.mgmt-eks.node_userdata

  node_instance_type = var.poet_node_instance_type
  node_ebs_size      = var.poet_node_ebs_size
  node_ssh_key       = var.ssh_bastion_key

  nodes_min = var.poet_nodes_min
  nodes_num = var.poet_nodes_num
  nodes_max = var.poet_nodes_max
}

### PoET Nodes: Access from MGMT
resource "aws_security_group_rule" "eks-poet-mgmt" {
  security_group_id = module.eks-poet.node_sg

  type       = "ingress"
  protocol   = "-1"
  from_port  = 0
  to_port    = 0

  cidr_blocks = [var.mgmt_vpc_cidr]
}

### PoET Nodes: Access from Master nodes
resource "aws_security_group_rule" "eks-poet-master" {
  security_group_id = module.eks-poet.node_sg

  type       = "ingress"
  protocol   = "-1"
  from_port  = 0
  to_port    = 0

  source_security_group_id = module.eks-master.node_sg
}

### Allow Jenkins to resize PoET pool
resource "aws_iam_role_policy_attachment" "jenkins-poet-resize" {
  role = aws_iam_role.jenkins.name
  policy_arn = module.eks-poet.policy_resize
}

### Outputs
output "poet_role_arn"  { value = module.eks-poet.node_role_arn }
output "poet_role_name" { value = module.eks-poet.node_role_name }

output "poet_asg" { value = module.eks-poet.node_scaling_group }

# vim:filetype=terraform ts=2 sw=2 et:
