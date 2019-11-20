### Vars
variable "fb_buffer_svc_port" { default = 31300 }

### Internal Fluent Bit Forwarder Load Balancer
module "fb-fwd-lb" {
  source = "../../../modules/lb-network/"

  name     = "${local.basename}-mgmt-fb-fwd"
  internal = true

  vpc_id  = module.mgmt-vpc.id
  subnets = module.mgmt-vpc.public_subnets

  listen_port = 24224
  target_port = var.fb_buffer_svc_port
  target_sg   = module.eks-logging.node_sg
}

# Attach Target Group to Logging EKS Nodes ASG
resource "aws_autoscaling_attachment" "fb-fwd" {
  autoscaling_group_name = module.eks-logging.node_scaling_group
  alb_target_group_arn   = module.fb-fwd-lb.target_group_arn
}

### Outputs
output "fb_fwd_host" { value = module.fb-fwd-lb.dns_name }

# vim:filetype=terraform ts=2 sw=2 et:
