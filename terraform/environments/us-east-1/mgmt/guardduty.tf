### KMS Key for GuardDuty
resource "aws_kms_key" "guardduty" {
  description = "Key for GuardDuty findings encryption"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "kms:GenerateDataKey",
      "Principal": {"Service": "guardduty.amazonaws.com"},
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "kms:*",
      "Principal": {"AWS": "arn:aws:iam::${var.aws_account}:root"},
      "Resource": "*"
    }
  ]
}
EOF
}

# User-friendly key alias
resource "aws_kms_alias" "guardduty" {
  name          = "alias/guardduty"
  target_key_id = aws_kms_key.guardduty.id
}

### Outputs
output "guardduty_key_id"    { value = aws_kms_key.guardduty.id }
output "guardduty_key_alias" { value = aws_kms_alias.guardduty.name }

# vim:filetype=terraform ts=2 sw=2 et:
