package io.spacemesh.awsinfra

class commons {
  static final aws_regions = [
    "ap-northeast-2",
    "eu-north-1",
    "us-east-1",
    "us-east-2",
    "us-west-2",
  ]
  static final aws_mgmt_region = "us-east-1"

  static final aws_poet_region = "us-east-1"
  static final poet_ctx = "mgmt-us-east-1"
  static final poet_pool_asg = "spacemesh-testnet-mgmt-us-east-1-poet"
  static final default_poet_image = "spacemeshos/poet:develop"

  static final default_miner_image = "spacemeshos/go-spacemesh:develop"
}

/* vim: set filetype=groovy ts=2 sw=2 et : */
