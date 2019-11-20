### Jenkins Security Group
resource "aws_security_group" "jenkins" {
  vpc_id      = module.mgmt-vpc.id
  name        = "${local.basename}-jenkins-${var.aws_region}"
  description = "SG for Jenkins instance"

  # Allow any egress
  egress {
    protocol  = "-1"
    from_port = 0
    to_port   = 0

    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # Allow SSH ingress
  ingress {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22

    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # Allow HTTP ingress
  ingress {
    protocol  = "tcp"
    from_port = 80
    to_port   = 80

    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # Allow HTTPS ingress
  ingress {
    protocol  = "tcp"
    from_port = 443
    to_port   = 443

    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${local.basename}-jenkins-${var.aws_region}"
  }
}

### Allow Jenkins to talk to EKS
resource "aws_security_group_rule" "mgmt-eks-jenkins" {
  security_group_id = module.mgmt-eks.sg

  description = "Full access from Jenkins"

  type       = "ingress"
  protocol   = "-1"
  from_port  = 0
  to_port    = 0

  source_security_group_id = aws_security_group.jenkins.id
}

### Jenkins IAM Role and Instance Profile
resource "aws_iam_role" "jenkins" {
  name = "${local.basename}-jenkins"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}
resource "aws_iam_instance_profile" "jenkins" {
  name = "${local.basename}-jenkins"
  role = aws_iam_role.jenkins.name
}

# Attach IAM Policy: Allow Jenkins to manage EKS Clusters
resource "aws_iam_role_policy_attachment" "jenkins-eks" {
  role = aws_iam_role.jenkins.name
  policy_arn = module.eks-roles.assume_admin_policy
}

# Inline IAM Policy: Allow Jenkins to describe instances
resource "aws_iam_role_policy" "jenkins-inline-ec2" {
  name = "ec2-describe-instances"
  role = aws_iam_role.jenkins.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:DescribeInstances",
      "Resource": "*"
    }
  ]
}
EOF
}

# Inline IAM Policy: Allow Jenkins to push container images to ECR
resource "aws_iam_role_policy" "jenkins-inline-ecr" {
  name = "ecr-push-image"
  role = aws_iam_role.jenkins.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["ecr:GetAuthorizationToken"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages",
        "ecr:BatchGetImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage"
      ],
      "Resource": [
        "${aws_ecr_repository.ecr-initfactory.arn}",
        "${aws_ecr_repository.ecr-miner-init.arn}"
      ]
    }
  ]
}
EOF
}

# Inline IAM Policy: Allow Jenkins to manipulate InitData
resource "aws_iam_role_policy" "jenkins-inline-initdata" {
  name = "testnet-initdata"
  role = aws_iam_role.jenkins.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:BatchGetItem",
        "dynamodb:BatchWriteItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:GetItem",
        "dynamodb:Scan",
        "dynamodb:Query",
        "dynamodb:UpdateItem"
      ],
      "Resource": "arn:aws:dynamodb:*:${var.aws_account}:table/${var.project_env}-initdata.*"
    },
    {
      "Effect": "Allow",
      "Action": [
          "dynamodb:Scan",
          "dynamodb:Query"
      ],
      "Resource": "arn:aws:dynamodb:*:${var.aws_account}:table/${var.project_env}-initdata.*/index/*"
    },
    {
      "Effect": "Allow",
      "Action": [ "s3:ListBucket", "s3:GetBucketLocation" ],
      "Resource": "arn:aws:s3:::testnet-initdata.*.spacemesh.io"
    },
    {
      "Effect": "Allow",
      "Action": [ "s3:GetObject*", "s3:PutObject*", "s3:DeleteObject*", "s3:RestoreObject" ],
      "Resource": "arn:aws:s3:::testnet-initdata.*.spacemesh.io/*"
    },
    {
      "Effect": "Allow",
      "Action": "s3:HeadBucket",
      "Resource": "*"
    }

  ]
}
EOF
}

### Jenkins EC2 Instance
resource "aws_instance" "jenkins" {
  ami           = data.aws_ami.centos7.id
  instance_type = var.mgmt_jenkins_instance_type

  key_name = var.ssh_admin_key

  # FIXME: random choice
  subnet_id = module.mgmt-vpc.public_subnets[3]

  vpc_security_group_ids = [
    aws_security_group.jenkins.id,
  ]

  iam_instance_profile = aws_iam_instance_profile.jenkins.name

  disable_api_termination = true

  tags = {
    Name = "${local.basename}-jenkins-${var.aws_region}"
  }

  volume_tags = {
    Name = "${local.basename}-jenkins-${var.aws_region}"
  }
}

### Jenkins EIP
resource "aws_eip" "jenkins" {
  vpc = true

  tags = {
    Name = "${local.basename}-jenkins-${var.aws_region}"
  }
}

resource "aws_eip_association" "jenkins" {
  instance_id   = aws_instance.jenkins.id
  allocation_id = aws_eip.jenkins.id
}



### Outputs
output "jenkins_ip"   { value = aws_eip.jenkins.public_ip }
output "jenkins_role" { value = aws_iam_role.jenkins.name }

# vim:filetype=terraform ts=2 sw=2 et:
