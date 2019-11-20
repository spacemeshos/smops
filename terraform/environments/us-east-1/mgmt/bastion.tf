### MGMT Bastion Instance
# Elastic IP
resource "aws_eip" "bastion" {
  vpc      = true
  instance = aws_instance.bastion.id

  tags = {
    Name = "${local.basename}-bastion-${var.aws_region}"
  }
}

# Security Group
resource "aws_security_group" "bastion" {
  vpc_id = module.mgmt-vpc.id
  name   = "${local.basename}-bastion-${var.aws_region}"

  description = "Security Group for bastion instance"

  # Allow SSH ingress
  ingress {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22

    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # Allow OpenVPN ingress
  ingress {
    protocol  = "udp"
    from_port = 1194
    to_port   = 1194

    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # Allow any egress
  egress {
    protocol  = "-1"
    from_port = 0
    to_port   = 0

    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${local.basename}-bastion-${var.aws_region}"
  }
}

# IAM Role and Instance Profile
resource "aws_iam_role" "bastion" {
  name = "${local.basename}-bastion"

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
resource "aws_iam_instance_profile" "bastion" {
  name = "${local.basename}-bastion"
  role = aws_iam_role.bastion.name
}

# Attach IAM Policy: Allow Bastion to manage EKS Clusters
resource "aws_iam_role_policy_attachment" "bastion-eks" {
  role = aws_iam_role.bastion.name
  policy_arn = module.eks-roles.assume_admin_policy
}

# Bastion Instance
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.centos7.id
  instance_type = var.mgmt_bastion_instance_type

  key_name = var.ssh_admin_key

  # FIXME: Random choice
  subnet_id = module.mgmt-vpc.public_subnets[3]

  vpc_security_group_ids = [
    aws_security_group.bastion.id,
  ]

  iam_instance_profile = aws_iam_instance_profile.bastion.name

  tags = {
    Name = "${local.basename}-bastion-${var.aws_region}"
  }

  volume_tags = {
    Name = "${local.basename}-bastion-${var.aws_region}"
  }
}

### Outputs
output "bastion_ip" { value = aws_eip.bastion.public_ip }
output "bastion_sg" { value = aws_security_group.bastion.id }

# vim:filetype=terraform ts=2 sw=2 et:
