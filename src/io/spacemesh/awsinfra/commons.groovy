/*
   Common constants related to spacemesh AWS infrastructure

   Example:

     import static io.spacemesh.awsinfra.commons.*

     aws_regions.each { ... }
*/

package io.spacemesh.awsinfra

class commons {
  /* The regions covered by TestNet */
  static final aws_regions = [
    "us-east-1",
    "us-east-2",
    "us-west-2",
    "ap-northeast-2",
    "eu-north-1",
  ]

  /* The region where management infrastructure runs */
  static final aws_mgmt_region = "us-east-1"
  /* Kubernetes context for management infrastructure */
  static final mgmt_ctx = "mgmt-us-east-1"

  /* The region where PoET runs */
  static final aws_poet_region = "us-east-1"
  /* Kubernetes context to manage PoET */
  static final poet_ctx = "mgmt-us-east-1"
  /* AWS Auto Scaling Group with PoET instance */
  static final poet_pool_asg = "spacemesh-testnet-mgmt-us-east-1-poet"
  /* PoET Pod resource limits */
  static final poet_cpu_limit = "7800m"
  static final poet_mem_limit = "30Gi"

  /* Default Docker container images */
  static final default_poet_image = "spacemeshos/poet:develop"
  static final default_miner_image = "spacemeshos/go-spacemesh:develop"
  static final default_initfactory_image = "spacemeshos/spacemeshos-initfactory:latest"
}

/* vim: set filetype=groovy ts=2 sw=2 et : */
