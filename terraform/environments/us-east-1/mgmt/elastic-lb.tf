### Target group for Elasticsearch
resource "aws_lb_target_group" "mgmt-es" {
  name     = "${local.basename}-mgmt-es"
  port     = 31200
  protocol = "HTTP"
  vpc_id   = module.mgmt-vpc.id
}

# Attach it to logging pool
resource "aws_autoscaling_attachment" "mgmt-es-logging" {
  autoscaling_group_name = module.eks-logging.node_scaling_group
  alb_target_group_arn   = aws_lb_target_group.mgmt-es.arn
}

### Target group for Kibana
resource "aws_lb_target_group" "mgmt-kibana" {
  name     = "${local.basename}-mgmt-kibana"
  port     = 31500
  protocol = "HTTP"
  vpc_id   = module.mgmt-vpc.id

  health_check {
    protocol = "HTTP"
    path     = "/app/kibana"
  }
}

# Attach it to logging pool
resource "aws_autoscaling_attachment" "mgmt-kibana-logging" {
  autoscaling_group_name = module.eks-logging.node_scaling_group
  alb_target_group_arn   = aws_lb_target_group.mgmt-kibana.arn
}

### LB Security Group
resource "aws_security_group" "logging-lbsg" {
  name        = "${local.basename}-logging-lbsg"
  vpc_id      = module.mgmt-vpc.id
  description = "SG for MGMT Logging load balancer"

  # No outbound restrictions
  egress {
    protocol  = "-1"
    from_port = 0
    to_port   = 0

    cidr_blocks      = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = [ "::/0" ]
  }

  # Access to Elasticsearch from internal network (VPC, Peered VPC, etc)
  ingress {
    protocol  = "tcp"
    from_port = 9200
    to_port   = 9200

    cidr_blocks = [ "10.0.0.0/8" ]
  }

  # Access to Kibana from internal network (VPC, Peered VPC, etc)
  ingress {
    protocol  = "tcp"
    from_port = 5601
    to_port   = 5601

    cidr_blocks = [ "10.0.0.0/8" ]
  }

  tags = {
    Name = "${local.basename}-logging-lbsg"
  }
}

### Allow LB to access NodePort services at targets
resource "aws_security_group_rule" "logging-lb-nodeport" {
  security_group_id = module.eks-logging.node_sg

  description = "Access to Elasticsearch from MGMT Logging load balancer"

  type      = "ingress"
  protocol  = "tcp"
  from_port = 30000
  to_port   = 32767

  source_security_group_id = aws_security_group.logging-lbsg.id
}

### MGMT Logging Application Load Balancer
resource "aws_lb" "logging-lb" {
  name                       = "spacemesh-testnet-mgmt-es"
  internal                   = "true"
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.logging-lbsg.id]
  subnets                    = module.mgmt-vpc.public_subnets
  enable_deletion_protection = false
  idle_timeout               = 600

  tags = {
    Name = "${local.basename}-mgmt-logging"
  }
}

# ES HTTP Listener - forward to Target Group
resource "aws_lb_listener" "logging-lb-es" {
  load_balancer_arn = aws_lb.logging-lb.arn
  port              = "9200"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mgmt-es.arn
  }
}

# Kibana HTTP Listener - forward to Target Group
resource "aws_lb_listener" "logging-lb-kibana" {
  load_balancer_arn = aws_lb.logging-lb.arn
  port              = "5601"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mgmt-kibana.arn
  }
}

### Outputs
output "mgmt_es" {
  value = {
    hostname = aws_lb.logging-lb.dns_name
    zone_id  = aws_lb.logging-lb.zone_id
  }
}

output "mgmt_kibana_url" { value = "http://${aws_lb.logging-lb.dns_name}:5601" } 

# vim:filetype=terraform ts=2 sw=2 et:
