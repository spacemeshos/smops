
### IAM Role for EKS worker nodes
resource "aws_iam_role" "eks-cluster-node" {
  name = "${var.basename}-node"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

# Attach default IAM policies
resource "aws_iam_role_policy_attachment" "eks-cluster-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks-cluster-node.name
}
resource "aws_iam_role_policy_attachment" "eks-cluster-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks-cluster-node.name
}

# Allow nodes to pull images from Container Registry
resource "aws_iam_role_policy_attachment" "eks-cluster-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks-cluster-node.name
}

### IAM Instance Profile for EKS worker nodes
resource "aws_iam_instance_profile" "eks-cluster-node" {
  name = "${var.basename}-node"
  role = aws_iam_role.eks-cluster-node.name
}

### EKS Node Launch Template
module "tpl" {
  source = "../launch-template/"

  name = var.basename

  ami_id          = var.node_ami
  instance_type   = var.node_instance_type
  ebs_dev         = "/dev/xvda"
  ebs_size        = var.node_ebs_size
  sg_id           = aws_security_group.eks-node.id
  assign_public_ip = var.assign_public_ip

  # EKS-specific bootstrap
  user_data  = base64encode(local.node_userdata)
  extra_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }

  key_name = var.node_ssh_key

  instance_profile = aws_iam_instance_profile.eks-cluster-node.name
}

### AutoScalingGroup
module "asg" {
  source = "../autoscaling-standalone/"

  name   = var.basename
  tpl_id = module.tpl.id

  min_size = var.nodes_min
  size     = var.nodes_num
  max_size = var.nodes_max

  vpc_id  = var.vpc_id
  subnets = var.subnets

  placement_strategy = var.placement_strategy

  extra_tags = var.pool == "" ? {} : merge(
    {
      "k8s.io/cluster-autoscaler/enabled" = "true"
      "k8s.io/cluster-autoscaler/${var.cluster_name}" = "true"
      "k8s.io/cluster-autoscaler/node-template/label/pool" = var.pool
    },
    var.taint ? { "k8s.io/cluster-autoscaler/node-template/taint/dedicated" = "${var.pool}:NoSchedule" } : {}
    )
}

# vim:filetype=terraform ts=2 sw=2 et:
