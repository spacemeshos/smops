### Variables
variable "bucket" {}
variable "name" {}
variable "location" {}
variable "versioning" { default = "true" }
variable "acl" { default = "private" }

### S3 Bucket
resource "aws_s3_bucket" "bucket" {
  bucket = "${var.bucket}"
  region = "${var.location}"
  acl    = "${var.acl}"

  versioning {
    enabled = "${var.versioning}"
  }

  # TODO: Add as a parameter
  lifecycle_rule {
    id      = "expire-old-versions"
    enabled = true

    abort_incomplete_multipart_upload_days = 1

    noncurrent_version_expiration {
      days = 7
    }
  }

  # TODO: Add as a parameter
  # Default SSE
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

# Ensure no public access is possible
resource "aws_s3_bucket_public_access_block" "bucket" {
  bucket = "${aws_s3_bucket.bucket.id}"

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

### IAM Policy: read-only access to bucket
resource "aws_iam_policy" "iam-s3-readonly" {
  name        = "${var.name}-access-readonly"
  path        = "/"
  description = "Allows read-only access to S3 ${var.bucket} bucket"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [ "s3:ListBucket", "s3:GetBucketLocation" ],
      "Resource": "${aws_s3_bucket.bucket.arn}"
    },
    {
      "Effect": "Allow",
      "Action": [ "s3:GetObject", "s3:GetObjectVersion", "s3:GetObjectTagging", "s3:GetObjectVersionTagging" ],
      "Resource": "${aws_s3_bucket.bucket.arn}/*"
    },
    {
      "Effect": "Allow",
      "Action": "s3:HeadBucket",
      "Resource": "*"
    }
  ]
}
EOF
}

### IAM Policy: full access to bucket
resource "aws_iam_policy" "iam-s3-fullaccess" {
  name        = "${var.name}-access-full"
  path        = "/"
  description = "Allows full access to S3 ${var.bucket} bucket"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [ "s3:ListBucket", "s3:GetBucketLocation" ],
      "Resource": "${aws_s3_bucket.bucket.arn}"
    },
    {
      "Effect": "Allow",
      "Action": [ "s3:GetObject*", "s3:PutObject*", "s3:DeleteObject*", "s3:RestoreObject" ],
      "Resource": "${aws_s3_bucket.bucket.arn}/*"
    },
    {
      "Effect": "Allow",
      "Action": "s3:HeadBucket",
      "Resource": "*"
    }
  ]
}
EOF
}

### Outputs
output "id" { value = "${aws_s3_bucket.bucket.id}" }

output "policy_readonly"   { value = "${aws_iam_policy.iam-s3-readonly.arn}" }
output "policy_fullaccess" { value = "${aws_iam_policy.iam-s3-fullaccess.arn}" }

# vim: set filetype=terraform ts=2 sw=2 et:
