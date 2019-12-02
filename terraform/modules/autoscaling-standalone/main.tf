### Variables
variable "name" {}
variable "min_size" { default = 1 }
variable "size"     { default = 0 }
variable "max_size" { default = 1 }
variable "tpl_id" {}
variable "vpc_id" {}
variable "subnets" { type = list }
variable "placement_strategy" { default = "" }
variable "extra_tags" {
  default = {}
  type = map(string)
}

### (Optional) Placement Group
resource "aws_placement_group" "asg-placement" {
  count    = var.placement_strategy == "" ? 0 : 1
  name     = var.name
  strategy = var.placement_strategy
}

### Standalone AutoScalingGroup ###
resource "aws_autoscaling_group" "asg" {
  name                = var.name
  vpc_zone_identifier = var.subnets

  desired_capacity = var.size > 0 ? var.size : var.min_size
  max_size         = var.max_size
  min_size         = var.min_size

  launch_template {
    id      = var.tpl_id
    version = "$Latest"
  }

  # (optionally) Attach Placement Group
  placement_group = var.placement_strategy == "" ? "" : aws_placement_group.asg-placement[0].name

  # Suspend AZRebalance
  suspended_processes = [ "AZRebalance" ]

  # Allow adjust group size outside of Terraform
  lifecycle {
    ignore_changes = [desired_capacity, vpc_zone_identifier]
  }

  # Add extra tags if instructed
  dynamic "tag" {
    for_each = var.extra_tags
    content {
      key   = tag.key
      value = tag.value

      propagate_at_launch = true
    }
  }
}

### Outputs ###
output "arn" { value = aws_autoscaling_group.asg.arn }
output "id"  { value = aws_autoscaling_group.asg.id }

# vim: set filetype=terraform ts=2 sw=2 et:
