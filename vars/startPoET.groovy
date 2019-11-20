/*
  Start PoET deployment step

  Example:

    startPoET image: "...", name: "poet1", params: [], aws_region: "us-east-1",
              pool: "testpoet", pool_asg: "spacemesh-testnet-mgmt-us-east-1-testpoet"

*/

import static io.spacemesh.awsinfra.common.*

def call(Map config) {
  /* Defaults */
  config = [
             image: default_poet_image,
             name: "poet",
             pool: "poet",
             pool_asg: poet_pool_asg,
             aws_region: aws_poet_region,
             params: [],
           ] + config

  def kubectl = "kubectl --context=${poet_ctx}"
  def params = """\"${config.params.join('", "')}\""""

  echo "Writing PoET manifest"
  writeFile file: "poet-deploy.yml",\
            text: """\
                  ---
                  apiVersion: apps/v1
                  kind: Deployment
                  metadata:
                    name: ${config.name}
                    labels:
                      app: ${config.name}
                  spec:
                    replicas: 1
                    selector:
                      matchLabels:
                        app: ${config.name}
                    template:
                      metadata:
                        labels:
                          app: ${config.name}
                      spec:
                        tolerations:
                          - effect: NoSchedule
                            key: dedicated
                            value: ${config.pool}
                            operator: Equal

                        nodeSelector:
                          pool: ${config.pool}

                        containers:
                          - name: default
                            image: ${config.image}
                            args: [
                              "--rpclisten", "0.0.0.0:50002",
                              "--restlisten", "0.0.0.0:8080",
                              ${params}
                            ]
                            ports:
                              - containerPort: 50002
                                hostPort: 50002
                                protocol: TCP
                              - containerPort: 8080
                                hostPort: 8080
                                protocol: TCP
                  """.stripIndent()

  echo "Ensure PoET pool has enough nodes"
  sh """\
     aws autoscaling update-auto-scaling-group \
                     --auto-scaling-group-name ${config.pool_asg} \
                     --region=${config.aws_region} \
                     --desired-capacity 1
     """.stripIndent()

  echo "Creating PoET deployment"
  sh """${kubectl} apply -f poet-deploy.yml"""

  echo "Waiting for the PoET pod to be scheduled"
  sh """${kubectl} wait --timeout=3600s --for=condition=Available deploy/${config.name}"""
}

/* vim: set filetype=groovy ts=2 sw=2 et : */
