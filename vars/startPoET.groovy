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
           ] + config

  def kubectl = "kubectl --context=${poet_ctx}"

  echo "config: ${config}"

  echo "Writing PoET entrypoint"
  writeFile file: "entrypoint.sh", text: '''\
    #!/bin/bash
    set -ex
    ARR=($(INITIALDURATION))
    echo "ARR:$ARR"
    I=${HOSTNAME##*-}
    echo "I:$I"
    ARGS="--reset --jsonlog --rpclisten '0.0.0.0:50002' --restlisten '0.0.0.0:8080'"
    ARGS+=" $(PARAMS)"
    ARGS+=" --initialduration ${ARR[$I]}"
    echo "ARGS:$ARGS"
    /bin/poet $ARGS
    '''.stripIndent()

  echo "Creating PoET configmap"
  sh """$kubectl create configmap poet-files --from-file=entrypoint.sh"""

  echo "Writing PoET manifest"
  writeFile file: "poet-deploy.yml",\
            text: """\
                  ---
                  apiVersion: apps/v1
                  kind: StatefulSet
                  metadata:
                    name: $config.name
                    labels:
                      app: $config.name
                  spec:
                    replicas: $config.count
                    selector:
                      matchLabels:
                        app: $config.name
                    strategy:
                      type: Recreate
                    template:
                      metadata:
                        labels:
                          app: $config.name
                      spec:
                        tolerations:
                          - effect: NoSchedule
                            key: dedicated
                            value: $config.pool
                            operator: Equal

                        nodeSelector:
                          pool: $config.pool

                        volumes:
                          - name: 
                            configMap:
                              name: poet-files
                              defaultMode: 0555

                        containers:
                          - name: default
                            image: $config.image
                            env:
                              - INITIALDURATION: $config.initialduration
                              - PARAMS: $config.params
                            command:
                              - /bin/sh
                              - "-c"
                              - |
                              apk -q add --update curl bash
                              /bin/bash entrypoint.sh
                            ports:
                              - containerPort: 50002
                                hostPort: 50002
                                protocol: TCP
                              - containerPort: 8080
                                hostPort: 8080
                                protocol: TCP
                            resources:
                              limits:
                                cpu: $poet_cpu_limit
                                memory: $poet_mem_limit
                              requests:
                                cpu: $poet_cpu_limit
                                memory: $poet_mem_limit
                  """.stripIndent()

  echo "Ensure PoET pool has enough nodes"
  sh """\
     aws autoscaling update-auto-scaling-group \
                     --auto-scaling-group-name $config.pool_asg \
                     --region=$config.aws_region \
                     --desired-capacity $config.count
     """.stripIndent()

  echo "Creating PoET deployment"
  sh """$kubectl apply -f poet-deploy.yml --validate=false"""

  count = config.count as Integer
  for (i = 0; i < count ; i++) {
    echo "Waiting for the poet-$i to be scheduled"
    sh """$kubectl wait --timeout=360s --for=condition=Available pod -l statefulset.kubernetes.io/pod-name=poet-$i"""
  }
}

/* vim: set filetype=groovy ts=2 sw=2 et : */
