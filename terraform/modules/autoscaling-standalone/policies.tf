### IAM Policy: Resize the group
resource "aws_iam_policy" "asg-resize" {
  name = "${var.name}-resize"
  path = "/"

  description = "Allow to view and resize ${var.name} AutoScalingGroup"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:BatchDeleteScheduledAction",
        "autoscaling:BatchPutScheduledUpdateGroupAction",
        "autoscaling:SetDesiredCapacity",
        "autoscaling:UpdateAutoScalingGroup",
        "autoscaling:TerminateInstanceInAutoScalingGroup",
        "autoscaling:DeleteScheduledAction",
        "autoscaling:PutScheduledUpdateGroupAction"
      ],
      "Resource": "${aws_autoscaling_group.asg.arn}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances "
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

### Outputs
output "policy_resize" { value = aws_iam_policy.asg-resize.arn }

# vim: set filetype=terraform ts=2 sw=2 et:
