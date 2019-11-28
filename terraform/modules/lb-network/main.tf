### Variables
variable "name" {}

variable "vpc_id"   {}
variable "subnets"  { type = list }
variable "internal" { default = false }

variable "listen_port" { default = 80 }
variable "target_port" { default = 80 }

variable "target_sg" {}

### SG Rule: Allow access to target port at targets
resource "aws_security_group_rule" "target" {
  security_group_id = var.target_sg

  description = "Public access to load balancer ${var.name} target port"

  type      = "ingress"
  protocol  = "tcp"
  from_port = var.target_port
  to_port   = var.target_port

  cidr_blocks      = [ "0.0.0.0/0" ]
  ipv6_cidr_blocks = [ "::/0" ]
}

### LoadBalancer
resource "aws_lb" "lb" {
  name                       = "${var.name}-lb"
  load_balancer_type         = "network"
  internal                   = var.internal
  subnets                    = var.subnets
  enable_deletion_protection = false

  tags = {
    Name = "${var.name}-lb"
  }
}

### Target group
resource "aws_lb_target_group" "tg" {
  name        = var.name
  port        = var.target_port
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = var.vpc_id
}

### Listener
resource "aws_lb_listener" "lb" {
  load_balancer_arn = aws_lb.lb.arn
  port              = var.listen_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

### Outputs
output "id"  { value = aws_lb.lb.id }
output "arn" { value = aws_lb.lb.arn }

output "target_group_id"  { value = aws_lb_target_group.tg.id }
output "target_group_arn" { value = aws_lb_target_group.tg.arn }

output "dns_name" { value = aws_lb.lb.dns_name }
output "zone_id"  { value = aws_lb.lb.zone_id }

# vim: set filetype=terraform ts=2 sw=2 et:
