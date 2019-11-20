### MGMT VPC Endpoints
# S3 Endpoint
module "s3-endpoint" {
  source = "../../../modules/vpc-endpoint-gateway/"

  name         = "${module.mgmt-vpc.name}-s3"
  vpc_id       = module.mgmt-vpc.id
  service_name = "com.amazonaws.${var.aws_region}.s3"

  route_tables = [
    module.mgmt-vpc.default_rt,
    module.mgmt-vpc.public_rt,
    module.mgmt-vpc.private_rt,
  ]
}

# DynamoDB Endpoint
module "dynamodb-endpoint" {
  source = "../../../modules/vpc-endpoint-gateway/"

  name         = "${module.mgmt-vpc.name}-dynamodb"
  vpc_id       = module.mgmt-vpc.id
  service_name = "com.amazonaws.${var.aws_region}.dynamodb"

  route_tables = [
    module.mgmt-vpc.default_rt,
    module.mgmt-vpc.public_rt,
    module.mgmt-vpc.private_rt,
  ]
}

# vim:filetype=terraform ts=2 sw=2 et:
