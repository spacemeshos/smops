### Variables
variable "name" { type = string}
variable "table_arn" { type = string }

## IAM Policy: Read-only access
resource "aws_iam_policy" "table-readonly" {
  name = "${var.name}-readonly"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:BatchGetItem",
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:Scan",
        "dynamodb:Query"
      ],
      "Resource": "${var.table_arn}"
    },
    {
      "Effect": "Allow",
      "Action": "dynamodb:ListTables",
      "Resource": "*"
    }
  ]
}
POLICY
}

## IAM Policy: Read/Write access
resource "aws_iam_policy" "table-readwrite" {
  name = "${var.name}-readwrite"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:BatchGetItem",
        "dynamodb:BatchWriteItem",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:ConditionCheck",
        "dynamodb:DescribeTable"
      ],
      "Resource": "${var.table_arn}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:Scan",
        "dynamodb:Query"
      ],
      "Resource": [
        "${var.table_arn}",
        "${var.table_arn}/index/*"
      ]
    }
  ]
}
POLICY
}

### Outputs
output "readonly"  { value = aws_iam_policy.table-readonly.arn }
output "readwrite" { value = aws_iam_policy.table-readwrite.arn }

# vim: set filetype=terraform ts=2 sw=2 et:
