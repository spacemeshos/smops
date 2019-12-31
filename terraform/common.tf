### Common variables
variable "mgmt_region"   { type = string }
variable "mgmt_vpc_cidr" { type = string }

variable "mgmt_master_instance_type" { default = "t3.small" }
variable "mgmt_master_ebs_size"      { default = 8 }

variable "mgmt_logging_instance_type" { default = "t3.medium" }
variable "mgmt_logging_ebs_size"      { default = 12 }
variable "mgmt_logging_pool_size"     { default = 8 }

variable "mgmt_jenkins_instance_type" { default = "t2.small" }
variable "mgmt_bastion_instance_type" { default = "t2.small" }

variable "aws_region"  { type = string }
variable "aws_account" { type = number }

variable "aws_region_list" { type = list }

variable "project_env"    { type = string }
variable "project_name"   { type = string }
variable "project_domain" { type = string }

variable "ssh_admin_key"   { type = string }
variable "ssh_bastion_key" { type = string }

### Region-specific setting
variable "default_subnet_bits" { default = 4 } # Depends on number of AZs in the region

### Miner parameters
variable "miner_vpc_cidr"        { type = string }
variable "miner_pvt_subnet_base" { default = 128 }

variable "miner_nodes_min" { default = 0 }
variable "miner_nodes_num" { default = 0 }
variable "miner_nodes_max" { default = 10 }

variable "miner_node_instance_type" { default = "t3.small" }
variable "miner_node_ebs_size"      { default = 12 }

variable "miner_master_instance_type" { default = "t3.small" }
variable "miner_master_ebs_size"      { default = 8 }

### InitFactory parameters
variable "initfactory_vpc_cidr" { type = string }

variable "initfactory_nodes_min" { default = 0 }
variable "initfactory_nodes_num" { default = 0 }
variable "initfactory_nodes_max" { default = 10 }


variable "initfactory_node_instance_type" { default = "t2.small" }
variable "initfactory_node_ebs_size"      { default = 12 }

variable "initfactory_master_instance_type" { default = "t3.small" }
variable "initfactory_master_ebs_size"      { default = 8 }

### PoET parameters
variable "poet_nodes_min" { default = 0 }
variable "poet_nodes_num" { default = 0 }
variable "poet_nodes_max" { default = 1 }

variable "poet_node_instance_type" { default = "t2.small" }
variable "poet_node_ebs_size"      { default = 12 }

### Handy locals
locals {
  basename                 = "${var.project_name}-${var.project_env}"
  clusters = {
    initfactory = "${local.basename}-initfactory-${var.aws_region}"
    miner       = "${local.basename}-miner-${var.aws_region}"
    mgmt        = "${local.basename}-mgmt-${var.mgmt_region}"
  }
}

# vim:filetype=terraform ts=2 sw=2 et:
