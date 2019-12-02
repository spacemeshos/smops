### CloudWatch Log Group for EKS logs
resource "aws_cloudwatch_log_group" "eks-logs" {
  name = "${var.project_name}-${var.project_env}-miner-${var.aws_region}"

  retention_in_days = 7
}

### IAM Policy: Put logs into EKS log group
resource "aws_iam_policy" "eks-put-logs" {
  name   = "${var.project_name}-${var.project_env}-miner-${var.aws_region}-put-logs"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow", 
      "Action": ["logs:DescribeLogGroups", "logs:DescribeLogStreams", "logs:CreateLogStream"],
      "Resource": "${aws_cloudwatch_log_group.eks-logs.arn}"
    },
    {
      "Effect": "Allow", 
      "Action": "logs:PutLogEvents",
      "Resource": "${aws_cloudwatch_log_group.eks-logs.arn}:log-stream:*"
    }
  ]
}
EOF
}

### Allow EKS master nodes to push logs
resource "aws_iam_role_policy_attachment" "master-eks-logs" {
  policy_arn = aws_iam_policy.eks-put-logs.arn
  role = module.eks-master.node_role_name
}

# vim:filetype=terraform ts=2 sw=2 et:
