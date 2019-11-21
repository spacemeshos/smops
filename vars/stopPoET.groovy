/*
  Stop PoET deployment step

  Example:

    startPoET name: "poet1", aws_region: "us-east-1",
              pool_asg: "spacemesh-testnet-mgmt-us-east-1-testpoet",
              keep_nodes: true

*/

import static io.spacemesh.awsinfra.commons.*

def call(config = [:]) {
  /* Defaults */
  config = [
             name: "poet",
             pool_asg: poet_pool_asg,
             aws_region: aws_poet_region,
             keep_nodes: false,
           ] + config

  def kubectl = "kubectl --context=${poet_ctx}"

  echo "Deleting PoET deployment"
  sh """${kubectl} delete deploy ${config.name} --ignore-not-found"""

  if(config.keep_nodes) {
    echo "Leaving PoET pool size as-is"
  } else {
    echo "Reducing PoET pool size to 0"
    sh """\
       aws autoscaling update-auto-scaling-group \
                       --auto-scaling-group-name ${config.pool_asg} \
                       --region=${config.aws_region} \
                       --desired-capacity 0
       """.stripIndent()
  }
}

/* vim: set filetype=groovy ts=2 sw=2 et : */
