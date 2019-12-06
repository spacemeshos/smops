### InitFactory CloudWatch Logs infra
module "cw-logs" {
  source = "../../../../../../modules/cloudwatch-logs/"

  aws_region  = var.aws_region
  aws_account = var.aws_account

  log_group_name = "${var.project_name}-${var.project_env}-initfactory-${var.aws_region}"

  logger_roles = [
    module.eks-master.node_role_name,
  ]
}

# vim:filetype=terraform ts=2 sw=2 et:
