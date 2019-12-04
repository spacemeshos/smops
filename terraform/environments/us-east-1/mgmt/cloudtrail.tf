### CloudWatch Log Group for EKS logs
module "cloudtrail" {
  source = "../../../modules/cloudtrail/"

  aws_region     = var.aws_region
  project_env    = var.project_env
  project_name   = var.project_name
  project_domain = var.project_domain
}

### Outputs
output "cloudtrail_name" { value = module.cloudtrail.name }
output "cloudtrail_arn"  { value = module.cloudtrail.arn }

output "cloudtrail_bucket"            { value = module.cloudtrail.bucket }
output "cloudtrail_bucket_readonly"   { value = module.cloudtrail.bucket_readonly }
output "cloudtrail_bucket_fullaccess" { value = module.cloudtrail.bucket_fullaccess }

# vim:filetype=terraform ts=2 sw=2 et:
