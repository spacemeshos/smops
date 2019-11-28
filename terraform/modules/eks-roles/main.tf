### Variables
variable "basename" { type = string }
variable "aws_account"  { type = string }

### IAM Role for EKS clusters
resource "aws_iam_role" "eks-cluster" {
  name = "${var.basename}-eks-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

# Attach default IAM policies
resource "aws_iam_role_policy_attachment" "eks-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-cluster.name
}
resource "aws_iam_role_policy_attachment" "eks-cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks-cluster.name
}

### IAM Role to create and manage EKS clusters
resource "aws_iam_role" "eks-admin" {
  name = "${var.basename}-eks-admin"

  # Allow EC2 instances and users to assume the role
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    },
    {
      "Effect": "Allow",
      "Principal": {"AWS": "arn:aws:iam::${var.aws_account}:root"},
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

# Inline policy: full access to EKS, allow passing cluster-role
resource "aws_iam_role_policy" "eks-admin" {
  role = aws_iam_role.eks-admin.name
  name = "eks-fullaccess"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "eks:*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "${aws_iam_role.eks-cluster.arn}"
    }
  ]
}
POLICY
}

### IAM Policy: Allow to assume the eks-admin role
resource "aws_iam_policy" "assume-eks-admin" {
  name = "${var.basename}-assume-eks-admin-role"

  description = "Allows the principal to assume ${var.basename}-eks-admin role"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "${aws_iam_role.eks-admin.arn}"
    }
  ]
}
POLICY
}

### Outputs
output "cluster_role_arn"  { value = aws_iam_role.eks-cluster.arn }
output "cluster_role_name" { value = aws_iam_role.eks-cluster.name }

# Here the name is fetched from inline policy to ensure it is created
# before use
output "admin_role_name" { value = aws_iam_role_policy.eks-admin.role }
output "admin_role_arn"  { value = "arn:aws:iam::${var.aws_account}:role/${aws_iam_role_policy.eks-admin.role}" }

output "assume_admin_policy" { value = aws_iam_policy.assume-eks-admin.arn }

# vim:filetype=terraform ts=2 sw=2 et:
