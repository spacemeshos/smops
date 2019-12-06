### Variables
variable "aws_region"     { type = string }
variable "aws_account"    { type = string }
variable "log_group_name" { type = string }

variable "log_retention" { default = 7 }
variable "logger_roles"  {
  type = set(string)
  default = []
}

### Locals
locals {
  log_group_base_arn = "arn:aws:logs:${var.aws_region}:${var.aws_account}:log-group"
  log_group_arn      = "${local.log_group_base_arn}:${var.log_group_name}"
}

### CloudWatch Log Group
resource "aws_cloudwatch_log_group" "logs" {
  name = var.log_group_name

  retention_in_days = var.log_retention
}

### IAM Policy: Put logs into log group
resource "aws_iam_policy" "put-logs" {
  name   = "${var.log_group_name}-put-logs"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DescribeLogGroupsInRegion",
      "Effect": "Allow",
      "Action": "logs:DescribeLogGroups",
      "Resource": "${local.log_group_base_arn}:*"
    },
    {
      "Sid": "CreateLogStreamsAndEvents",
      "Effect": "Allow",
      "Action": ["logs:PutLogEvents", "logs:DescribeLogStreams", "logs:CreateLogStream"],
      "Resource": "${local.log_group_arn}:log-stream:*"
    }
  ]
}
EOF
}

### Attach IAM Policy to the roles
resource "aws_iam_role_policy_attachment" "put-logs" {
  for_each   = var.logger_roles
  role       = each.value
  policy_arn = aws_iam_policy.put-logs.arn
}

### Outputs
output "id"   { value = aws_cloudwatch_log_group.logs.id }
output "name" { value = var.log_group_name }
output "arn"  { value = local.log_group_arn }

output "put_logs_arn"  { value = aws_iam_policy.put-logs.arn }

# vim:filetype=terraform ts=2 sw=2 et:
