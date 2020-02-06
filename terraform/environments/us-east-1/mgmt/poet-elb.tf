### Variables
variable "poet_port" { default = 8080 }

### PoET REST Load Balancer
module "poet-grpc-lb" {
  source = "../../../modules/lb-network/"

  name = "${local.basename}-poet-grpc"

  vpc_id  = module.mgmt-vpc.id
  subnets = module.mgmt-vpc.public_subnets

  listen_port = var.poet_port
  target_port = var.poet_port
  target_sg   = module.eks-poet.node_sg
}

# Attach Target Group to PoET EKS Nodes ASG
resource "aws_autoscaling_attachment" "poet-grpc" {
  autoscaling_group_name = module.eks-poet.node_scaling_group
  alb_target_group_arn   = module.poet-grpc-lb.target_group_arn
}

### Outputs
output "poet_url" { value = "${module.poet-grpc-lb.dns_name}:${var.poet_port}" }

# vim:filetype=terraform ts=2 sw=2 et:
