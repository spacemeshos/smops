### InitFactory VPC Endpoints
# S3 Endpoint
module "s3-endpoint" {
  source = "../../../../../../modules/vpc-endpoint-gateway/"

  name         = "${module.initfactory-vpc.name}-s3"
  vpc_id       = module.initfactory-vpc.id
  service_name = "com.amazonaws.${var.aws_region}.s3"

  route_tables = [
    module.initfactory-vpc.default_rt,
    module.initfactory-vpc.public_rt,
    aws_route_table.initfactory-private.id,
  ]
}

# DynamoDB Endpoint
module "dynamodb-endpoint" {
  source = "../../../../../../modules/vpc-endpoint-gateway/"

  name         = "${module.initfactory-vpc.name}-dynamodb"
  vpc_id       = module.initfactory-vpc.id
  service_name = "com.amazonaws.${var.aws_region}.dynamodb"

  route_tables = [
    module.initfactory-vpc.default_rt,
    module.initfactory-vpc.public_rt,
    aws_route_table.initfactory-private.id,
  ]
}

### Outputs
output "s3_gw"       { value = module.s3-endpoint.id }
output "dynamodb_gw" { value = module.dynamodb-endpoint.id }

# vim:filetype=terraform ts=2 sw=2 et:
