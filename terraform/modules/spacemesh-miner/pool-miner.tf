### EKS Miner node pool
module "eks-miner" {
  source = "../../../../../../modules/eks-nodes/"

  basename = "${local.clusters.miner}-miner"

  pool = "miner"

  cluster_name = local.clusters.miner
  cluster_sg   = module.miner-eks.sg

  aws_region         = var.aws_region
  vpc_id             = module.miner-vpc.id
  subnets            = module.miner-vpc.public_subnets
  placement_strategy = "cluster"

  # Miners should have external IP available
  assign_public_ip = true

  node_ami      = module.miner-eks.node_ami
  node_userdata = module.miner-eks.node_userdata

  node_instance_type = var.miner_node_instance_type
  node_ebs_size      = var.miner_node_ebs_size
  node_ssh_key       = var.ssh_bastion_key

  nodes_min = var.miner_nodes_min
  nodes_num = var.miner_nodes_num
  nodes_max = var.miner_nodes_max
}

### Miner Nodes: Access from MGMT
resource "aws_security_group_rule" "eks-miner-mgmt" {
  security_group_id = module.eks-miner.node_sg

  type       = "ingress"
  protocol   = "-1"
  from_port  = 0
  to_port    = 0

  cidr_blocks = [var.mgmt_vpc_cidr]
}

### Miner Nodes: Access from Master nodes
resource "aws_security_group_rule" "eks-miner-master" {
  security_group_id = module.eks-miner.node_sg

  type       = "ingress"
  protocol   = "-1"
  from_port  = 0
  to_port    = 0

  source_security_group_id = module.eks-master.node_sg
}

### Miner Nodes: Public access to services
# TCP Services
resource "aws_security_group_rule" "eks-miner-tcp-services" {
  security_group_id = module.eks-miner.node_sg

  description = "Allow public access to TCP Services"

  type        = "ingress"
  protocol    = "tcp"
  from_port   = 30000
  to_port     = 32767

  cidr_blocks      = ["0.0.0.0/0"]
  ipv6_cidr_blocks = ["::/0"]
}

# TCP nodePorts
resource "aws_security_group_rule" "eks-miner-tcp-nodeport" {
  security_group_id = module.eks-miner.node_sg

  description = "Allow public access to TCP nodePorts"

  type        = "ingress"
  protocol    = "tcp"
  from_port   = 62000
  to_port     = 65535

  cidr_blocks      = ["0.0.0.0/0"]
  ipv6_cidr_blocks = ["::/0"]
}

# UDP Services
resource "aws_security_group_rule" "eks-miner-udp-services" {
  security_group_id = module.eks-miner.node_sg

  description = "Allow public access to UDP Services"

  type        = "ingress"
  protocol    = "udp"
  from_port   = 30000
  to_port     = 32767

  cidr_blocks      = ["0.0.0.0/0"]
  ipv6_cidr_blocks = ["::/0"]
}

# UDP nodePorts
resource "aws_security_group_rule" "eks-miner-udp-nodeport" {
  security_group_id = module.eks-miner.node_sg

  description = "Allow public access to UDP nodePorts"

  type        = "ingress"
  protocol    = "udp"
  from_port   = 62000
  to_port     = 65535

  cidr_blocks      = ["0.0.0.0/0"]
  ipv6_cidr_blocks = ["::/0"]
}

# ICMP (for network diagnositcs)
resource "aws_security_group_rule" "eks-miner-icmp" {
  security_group_id = module.eks-miner.node_sg

  description = "Allow ICMP"

  type        = "ingress"
  protocol    = "icmp"
  from_port   = -1
  to_port     = -1

  cidr_blocks      = ["0.0.0.0/0"]
  ipv6_cidr_blocks = ["::/0"]
}

### Miner Nodes: IAM Policies
# Allow miners to update DynamoDB
resource "aws_iam_role_policy_attachment" "miner-dynamodb-readwrite" {
  role = module.eks-miner.node_role_name
  policy_arn = local.initdata_dynamodb_readwrite
}

resource "aws_iam_role_policy_attachment" "miner-s3-readonly" {
  role = module.eks-miner.node_role_name
  policy_arn = local.initdata_s3_readonly
}

### Allow master to resize miner pool
resource "aws_iam_role_policy_attachment" "eks-master-miner-resize" {
  role = module.eks-master.node_role_name
  policy_arn = module.eks-miner.policy_resize
}


### Outputs
output "miner_role_arn"  { value = module.eks-miner.node_role_arn }
output "miner_role_name" { value = module.eks-miner.node_role_name }

output "miner_asg" { value = module.eks-miner.node_scaling_group }

# vim:filetype=terraform ts=2 sw=2 et:
