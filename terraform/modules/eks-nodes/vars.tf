### Inputs
variable "aws_region" { type = string }
variable "vpc_id" { type = string }
variable "subnets" { type = list }
variable "basename" { type = string }
variable "cluster_name" { type = string }
variable "cluster_sg" { type = string }
variable "node_ami" { type = string }
variable "node_userdata" { type = string }
variable "nodes_min" { default = 1 }
variable "nodes_num" { default = 1 }
variable "nodes_max" { default = 1 }
variable "node_instance_type" { default = "t2.small" }
variable "node_ebs_size" { default = 20 }
variable "node_ssh_key" { type = string }
variable "kubelet_args" { default = "" }
variable "access_to_sgs" { default = [] }
variable "access_from_sgs" { default = [] }
variable "assign_public_ip" { default = false }
variable "pool" { default = "" }
variable "taint" { default = true }
variable "placement_strategy" { default = "" }

### Locals
locals {
  # Add pool-related config to kubelet_extra_args
  _extra_kubelet_taints = var.taint ? "--register-with-taints dedicated=${var.pool}:NoSchedule " : ""
  _extra_kubelet_args = var.pool == "" ? var.kubelet_args : "${chomp(var.kubelet_args)} ${local._extra_kubelet_taints}--node-labels pool=${var.pool},kubernetes.io/role=${var.pool}"

  # Append kubelet extra arguments if required
  node_userdata = local._extra_kubelet_args == "" ? var.node_userdata : "${chomp(var.node_userdata)} --kubelet-extra-args \"${local._extra_kubelet_args}\""
}

# vim:filetype=terraform ts=2 sw=2 et:
