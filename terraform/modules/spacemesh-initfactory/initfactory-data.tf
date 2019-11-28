### InitFactory S3 Bucket
module "initdata-s3" {
  source = "../../../../../../modules/s3-bucket/"

  name     = "initdata-${var.aws_region}"
  bucket   = "${var.project_env}-initdata.${var.aws_region}.${var.project_domain}"
  location = var.aws_region
}

### InitFactory S3 Bucket: Access
# Full access for InitFactory
resource "aws_iam_role_policy_attachment" "initfactory-s3-fullaccess" {
  role       = module.eks-initfactory.node_role_name
  policy_arn = module.initdata-s3.policy_fullaccess
}

### InitFactory DynamoDB table
resource "aws_dynamodb_table" "initdata" {
  name = "${var.project_env}-initdata.${var.aws_region}.${var.project_domain}"

  billing_mode = "PAY_PER_REQUEST"

  # Primary key
  attribute {
      name = "id"
      type = "S"
  }
  hash_key  = "id"

  # Randomized order index
  attribute {
    name = "locked"
    type = "N"
  }
  attribute {
    name = "random_sort_key"
    type = "N"
  }
  global_secondary_index {
    name     = "locked_random"
    hash_key = "locked"
    range_key = "random_sort_key"

    projection_type    = "INCLUDE"
    non_key_attributes = ["space", "id"]
  }

  # Locked by index
  attribute {
    name = "locked_by"
    type = "S"
  }
  global_secondary_index {
    name     = "locked_by"
    hash_key = "locked_by"

    projection_type    = "INCLUDE"
    non_key_attributes = ["id"]
  }

  # Index by space
  attribute {
    name = "space"
    type = "N"
  }
  global_secondary_index {
    name     = "space"
    hash_key = "space"

    projection_type    = "INCLUDE"
    non_key_attributes = ["id"]
  }

  # Recommended
  lifecycle {
    ignore_changes = [read_capacity, write_capacity]
  }
}

### IAM Policy: DynamoDB Read/Write access
resource "aws_iam_policy" "initdata-dynamodb-readwrite" {
  name = "${local.basename}-initdata-dynamodb-${var.aws_region}-readwrite"
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
      "Resource": "${aws_dynamodb_table.initdata.arn}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:Scan",
        "dynamodb:Query"
      ],
      "Resource": [
        "${aws_dynamodb_table.initdata.arn}",
        "${aws_dynamodb_table.initdata.arn}/index/*"
      ]
    }
  ]
}
POLICY
}

### InitFactory DynamoDB Table: Access
# Full access for InitFactory
resource "aws_iam_role_policy_attachment" "initfactory-dynamodb-fullaccess" {
  role       = module.eks-initfactory.node_role_name
  policy_arn = aws_iam_policy.initdata-dynamodb-readwrite.arn
}

### Outputs
output "initdata-dynamodb" {
  value = {
    table            = aws_dynamodb_table.initdata.id
    policy_readwrite = aws_iam_policy.initdata-dynamodb-readwrite.arn
  }
}

output "initdata-s3" {
  value = {
    bucket            = module.initdata-s3.id
    policy_readonly   = module.initdata-s3.policy_readonly
    policy_fullaccess = module.initdata-s3.policy_fullaccess
  }
}

# vim:filetype=terraform ts=2 sw=2 et:
