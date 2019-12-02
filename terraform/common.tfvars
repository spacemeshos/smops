# Project-wide defaults
project_name   = "spacemesh"
project_domain = "spacemesh.io"
aws_account    = 534354616613

aws_region_list = [
  "ap-northeast-2",
  "eu-north-1",
  "us-east-1",
  "us-east-2",
  "us-west-2",
]

# Access params
ssh_admin_key   = "spacemesh"
ssh_bastion_key = "spacemesh"

# MGMT params
mgmt_region   = "us-east-1"
mgmt_vpc_cidr = "10.108.0.0/16"

mgmt_master_instance_type = "t3.small"
mgmt_master_ebs_size      = 8

# Miner EKS params
miner_master_instance_type = "t3.small"
miner_master_ebs_size      = 8

# Miner pool params
miner_node_instance_type = "c5.2xlarge"
miner_node_ebs_size = 12
miner_nodes_max = 50

# InitFactory EKS params
initfactory_master_instance_type = "t3.small"

# InitFactory pool params
initfactory_node_instance_type = "c5.2xlarge"
initfactory_nodes_min = 0
initfactory_nodes_num = 1
initfactory_nodes_max = 40

# PoET parameters
poet_node_instance_type = "m5a.large"
poet_node_ebs_size      = 12

# MGMT Elasticsearch parameters
mgmt_logging_instance_type = "r5.2xlarge"

# vim:filetype=terraform ts=2 sw=2 et:
