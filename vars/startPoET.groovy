/*
  Start PoET deployment step

  Example:

    startPoET image: "...", name: "poet1", params: [], aws_region: "us-east-1",
              pool: "testpoet", pool_asg: "spacemesh-testnet-mgmt-us-east-1-testpoet"

*/

import static io.spacemesh.awsinfra.commons.*

def call(config = [:]) {
  /* Defaults */
  config = [
             image: default_poet_image,
             name: "poet",
             pool: "poet",
             pool_asg: poet_pool_asg,
             aws_region: aws_poet_region,
             params: [],
             initialduration: [],
           ] + config

  def kubectl = "kubectl --context=${poet_ctx}"

  echo "config: ${config}"

  echo "Writing PoET manifest"
  writeFile file: "poet-deploy.yml",\
            text: """\
                  ---
                  apiVersion: apps/v1
                  kind: StatefulSet
                  metadata:
                    name: ${config.name}
                    labels:
                      app: ${config.name}
                  spec:
                    replicas: ${config.count}
                    selector:
                      matchLabels:
                        app: ${config.name}
                    strategy:
                      type: Recreate
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
                            command:
                              - /bin/sh
                              - "-c"
                              - |
                              /bin/sh <<'EOF'
                              INITIALDURATION="${config.initialduration}"
                              echo "INITIALDURATION:\${INITIALDURATION}"
                              ARR=(\${INITIALDURATION})
                              echo "ARR:\${ARR}"
                              N=\${HOSTNAME##*-}
                              echo "N:\${N}"
                              PARAMS="${config.params} --initialduration \${ARR[\${N}]}"
                              echo "PARAMS:\${PARAMS}"
                              CMD="/bin/poet --reset --rpclisten '0.0.0.0:50002' --restlisten '0.0.0.0:8080' \$PARAMS"
                              echo "\${CMD}"
                              $(CMD)
                              EOF
                            ports:
                              - containerPort: 50002
                                hostPort: 50002
                                protocol: TCP
                              - containerPort: 8080
                                hostPort: 8080
                                protocol: TCP
                            resources:
                              limits:
                                cpu: ${poet_cpu_limit}
                                memory: ${poet_mem_limit}
                              requests:
                                cpu: ${poet_cpu_limit}
                                memory: ${poet_mem_limit}
                  """.stripIndent()

  echo "Ensure PoET pool has enough nodes"
  sh """\
     aws autoscaling update-auto-scaling-group \
                     --auto-scaling-group-name ${config.pool_asg} \
                     --region=${config.aws_region} \
                     --desired-capacity ${config.count}
     """.stripIndent()

  echo "Creating PoET deployment"
  sh """${kubectl} apply -f poet-deploy.yml --validate=false"""

  count = config.count as Integer
  for (i = 0; i < count ; i++) {
    echo "Waiting for the poet-${i} to be scheduled"
    sh """${kubectl} wait --timeout=360s --for=condition=Available pod -l statefulset.kubernetes.io/pod-name=poet-${i}"""
  }
}

/* vim: set filetype=groovy ts=2 sw=2 et : */
