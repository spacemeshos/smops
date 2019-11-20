### Variables
variable "name" {}
variable "ami_id" {}
variable "instance_type" {}
variable "key_name" { default = "" }
variable "ebs_dev" { default = "/dev/sda1" }
variable "ebs_size" {}
variable "sg_id" {}
variable "instance_profile" {}
variable "user_data" { default = "" }
variable "extra_tags" { default = {} }
variable "assign_public_ip" { default = false }

### LaunchTemplate ###
resource "aws_launch_template" "tpl" {
  name          = "${var.name}"
  image_id      = "${var.ami_id}"
  instance_type = "${var.instance_type}"
  key_name      = "${var.key_name}"
  user_data     = "${var.user_data}"

  block_device_mappings {
    device_name = var.ebs_dev

    ebs {
      volume_type           = "gp2"
      volume_size           = "${var.ebs_size}"
      delete_on_termination = true
    }
  }

  network_interfaces {
    security_groups             = ["${var.sg_id}"]
    delete_on_termination       = true
    associate_public_ip_address = var.assign_public_ip
  }

  iam_instance_profile {
    name = "${var.instance_profile}"
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(var.extra_tags, {
      Name = "${var.name}"
    })
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name = "${var.name}"
    }
  }

  lifecycle {
    ignore_changes = ["image_id", "latest_version"]
  }
}

### IAM Policy: Allow CreateLaunchTemplateVersion on the template ###
resource "aws_iam_policy" "iam-tpl-versions" {
  name        = "${var.name}-modify-versions"
  path        = "/"
  description = "Allows adding and removing ${var.name} versions"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [ "ec2:DeleteLaunchTemplateVersions", "ec2:CreateLaunchTemplateVersion" ],
      "Resource": "${aws_launch_template.tpl.arn}"
    }
  ]
}
EOF
}

### OUTPUTS ###
output "id" {
  value = "${aws_launch_template.tpl.id}"
}
output "arn" {
  value = "${aws_launch_template.tpl.arn}"
}

output "policy_modify_versions" {
  value = "${aws_iam_policy.iam-tpl-versions.id}"
}

# vim: set filetype=terraform ts=2 sw=2 et:
