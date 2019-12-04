### Variables
variable "project_name"   { type = string }
variable "project_env"    { type = string }
variable "project_domain" { type = string }
variable "aws_region"     { type = string }

variable "trail_depth" { default = 365 }

### Locals
locals {
  bucket = "${var.project_env}-cloudtrail.${var.aws_region}.${var.project_domain}"
  name   = "${var.project_name}-${var.project_env}-${var.aws_region}-cloudtrail"
}

### S3 Bucket to store logs
module "logs-bucket" {
  source = "../s3-bucket/"

  bucket   = local.bucket
  name     = "${var.project_name}-${var.project_env}-${var.aws_region}-cloudtrail"
  location = var.aws_region

  versions_ttl = var.trail_depth
  objects_ttl  = var.trail_depth
}

### S3 Bucket Policy: Allow CloudTrail to save logs
resource "aws_s3_bucket_policy" "logs-bucket" {
  depends_on = [module.logs-bucket]

  bucket = local.bucket
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:GetBucketAcl",
      "Principal": {"Service": "cloudtrail.amazonaws.com"},
      "Resource": "arn:aws:s3:::${local.bucket}"
    },
    {
      "Effect": "Allow",
      "Action": "s3:PutObject",
      "Principal": {"Service": "cloudtrail.amazonaws.com"},
      "Resource": "arn:aws:s3:::${local.bucket}/AWSLogs/*",
      "Condition": {"StringEquals": {"s3:x-amz-acl": "bucket-owner-full-control"}}
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetBucketAcl", "s3:GetBucketLocation"],
      "Principal": {"Service": "guardduty.amazonaws.com"},
      "Resource": "arn:aws:s3:::${local.bucket}"
    },
    {
      "Effect": "Allow",
      "Action": "s3:PutObject",
      "Principal": {"Service": "guardduty.amazonaws.com"},
      "Resource": "arn:aws:s3:::${local.bucket}/AWSLogs/*",
      "Condition": {"StringEquals": {"s3:x-amz-server-side-encryption": "aws:kms"}}
    },
    {
      "Effect": "Allow",
      "Action": "s3:GetBucketAcl",
      "Principal": {"Service": "delivery.logs.amazonaws.com"},
      "Resource": "arn:aws:s3:::${local.bucket}"
    },
    {
      "Effect": "Allow",
      "Action": "s3:PutObject",
      "Principal": {"Service": "delivery.logs.amazonaws.com"},
      "Resource": "arn:aws:s3:::${local.bucket}/AWSFlow/*"
    }
  ]
}
EOF
}

### CloudTrail: All events to S3 Bucket
resource "aws_cloudtrail" "trail" {
  depends_on = [aws_s3_bucket_policy.logs-bucket]

  name           = local.name
  s3_bucket_name = local.bucket

  is_multi_region_trail = true
}

### Outputs
output "name" { value = local.name }
output "arn"  { value = aws_cloudtrail.trail.arn }

output "bucket"            { value = local.bucket }
output "bucket_fullaccess" { value = module.logs-bucket.policy_fullaccess }
output "bucket_readonly"   { value = module.logs-bucket.policy_readonly }

# vim:filetype=terraform ts=2 sw=2 et:
