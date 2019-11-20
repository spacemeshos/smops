# Availability zones
data "aws_availability_zones" "aws_azs" {}

# Latest CentOS 7 AMI in the region (needs manual subscription)
data "aws_ami" "centos7" {
  executable_users = ["all"]
  owners           = ["aws-marketplace"]
  most_recent      = true

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "owner-id"
    values = ["679593333241"]
  }

  filter {
    name   = "product-code"
    values = ["aw0evgkw8e5c1q413zgy5pjce"]
  }
}

# vim:filetype=terraform ts=2 sw=2 et:
