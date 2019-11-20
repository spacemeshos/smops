### EKS Master node pool
module "eks-master" {
  source = "../../../modules/eks-nodes/"

  basename = "${local.clusters.mgmt}-master"
  pool     = "master"
  taint    = false

  cluster_name = local.clusters.mgmt
  cluster_sg   = module.mgmt-eks.sg

  aws_region       = var.aws_region
  vpc_id           = module.mgmt-vpc.id
  subnets          = module.devops-subnets.ids

  node_ami      = module.mgmt-eks.node_ami
  node_userdata = module.mgmt-eks.node_userdata

  node_instance_type = var.mgmt_master_instance_type
  node_ebs_size      = var.mgmt_master_ebs_size
  node_ssh_key       = var.ssh_bastion_key

  nodes_min = 1
  nodes_num = 1
  nodes_max = 1
}

### IAM Policy: Allow master nodes to scrape the cluster
resource "aws_iam_role_policy" "eks-master-scraper" {
  name = "scraper-policy"
  role = module.eks-master.node_role_name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:DescribeVolumes",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "cloudwatch:PutMetricData",
      "Resource": "*"
    }
  ]
}
EOF
}

### Master Nodes: Access to CoreDNS
resource "aws_security_group_rule" "eks-master-coredns" {
  security_group_id = module.eks-master.node_sg

  type       = "ingress"
  protocol   = "udp"
  from_port  = 53
  to_port    = 53

  cidr_blocks = [var.mgmt_vpc_cidr]
}

### Master Nodes: Access from bastion
resource "aws_security_group_rule" "bastion-eks-master" {
  security_group_id = module.eks-master.node_sg

  type       = "ingress"
  protocol   = "-1"
  from_port  = 0
  to_port    = 65535

  source_security_group_id = aws_security_group.bastion.id
}

### Outputs
output "master_role_arn"  { value = module.eks-master.node_role_arn }
output "master_role_name" { value = module.eks-master.node_role_name }

# vim:filetype=terraform ts=2 sw=2 et:
