### ECR
resource "aws_ecr_repository" "ecr-initfactory" {
  name = "${local.basename}-initfactory"
}

resource "aws_ecr_repository" "ecr-miner-init" {
  name = "${local.basename}-miner-init"
}

resource "aws_ecr_repository" "ecr-metrics-scraper" {
  name = "${local.basename}-metrics-scraper"
}

/*
### Allow all users to push and pull images
resource "aws_ecr_repository_policy" "ecr-users-fullaccess" {
  repository = aws_ecr_repository.ecr.name

  policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DeleteRepository",
        "ecr:BatchDeleteImage"
      ],
      "Principal": {"AWS": "arn:aws:iam::${var.aws_account}:user/*"}
    }
  ]
}
EOF
}
*/

### Outputs
output "ecr_initfactory"     { value = aws_ecr_repository.ecr-initfactory.repository_url }
output "ecr_miner_init"      { value = aws_ecr_repository.ecr-miner-init.repository_url }
output "ecr_metrics_scraper" { value = aws_ecr_repository.ecr-metrics-scraper.repository_url }

# vim:filetype=terraform ts=2 sw=2 et:
