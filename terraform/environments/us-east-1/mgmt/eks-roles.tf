### Common EKS role(s)
module "eks-roles" {
  source = "../../../modules/eks-roles/"

  basename     = var.project_name # FIXME: No "testnet" here
  aws_account  = var.aws_account
}

### Outputs
output "eks_admin_role"   { value = module.eks-roles.admin_role_arn }
output "eks_cluster_role" { value = module.eks-roles.cluster_role_arn }

# vim:filetype=terraform ts=2 sw=2 et:
