/*
  Start TestNet bootstrap node in the region

  Example:

    startBootstrapNode aws_region: "us-east-1", pool_id: "test01", \
                       init_miner_image: "...", miner_image: "...", vol_size: "300", port: 65100, \
                       spacemesh_space: "1048576", cpu_limit: "1950m", cpu_requests: "1950m", \
                       params: []
*/

def call(Map config) {
  /* Defaults */
  config = [cpu_limit: "1950m", cpu_requests: "1950m", grpc_port: 9091, params: [], ] + config

  kubectl = "kubectl --context=miner-${config.aws_region}"

  echo "Writing service manifest"
  node = "miner-${config.pool_id}-bootstrap"
  writeFile file: "${node}-svc.yml",\
            text: """\
                  ---
                  apiVersion: v1
                  kind: Service
                  metadata:
                    name: ${node}
                    labels:
                      app: miner
                      miner-pool: \"${config.pool_id}\"
                  spec:
                    type: NodePort
                    selector:
                      app: miner
                      miner-node: bootstrap
                      miner-pool: \"${config.pool_id}\"
                    ports:
                    - protocol: TCP
                      port: ${config.grpc_port}
            """.stripIndent()
  echo "Creating service"
  sh """${kubectl} create --save-config -f ${node}-svc.yml"""

  echo "Getting allocated port"
  bootstrap_grpc_port = shell("""${kubectl} get svc ${node} --template '{{(index .spec.ports 0).nodePort}}'""")
  echo " >>> Bootstrap GRPC port: ${bootstrap_grpc_port}"

  startMinerNode(config + [
    node_id: "bootstrap",
    params: config.params + ["--grpc-server", "--grpc-port", config.grpc_port],
  ])

  echo "Waiting for the bootstrap pod to be scheduled"
  sh """${kubectl} wait --timeout=3600s --for=condition=Available deploy/${node}"""

  echo "Getting the node which runs the pod"

  (bootstrap_pod, pod_status, pod_node) = shell("""\
    ${kubectl} get pod -l miner-pool=${config.pool_id},miner-node=bootstrap \\
       --template '{{\$i := index .items 0 }}{{\$i.metadata.name}} {{\$i.status.phase}} {{\$i.spec.nodeName}}' \\
       2>/dev/null
  """.stripIndent().trim()).split()

  echo "Running on node ${pod_node}, getting AWS instance id"
  inst_id = shell("""\
    ${kubectl} get node ${pod_node} --template '{{.spec.providerID}}' | sed -e 's/.\\+\\///'
  """.stripIndent())

  echo "Running on EC2 instance '${inst_id}', getting its public IP"
  bootstrap_addr = shell("""\
    aws ec2 describe-instances --region=${config.aws_region} --instance-ids ${inst_id} \\
                               --query 'Reservations[0].Instances[0].PublicIpAddress' --output text
    """.stripIndent().trim())

  echo "Bootstrapping from: ${bootstrap_addr}:${config.port}"

  echo "Getting bootstrap miner_id from the logs"
  retry(10) {
    bootstrap_id = shell("""\
      ${kubectl} logs ${bootstrap_pod} |\\
        sed -ne '/Local node identity / { s/.\\+Local node identity >> \\([a-zA-Z0-9]\\+\\).*/\\1/ ; p; q; }'
    """.stripIndent().trim())
  }
  echo "Bootstrap ID: ${bootstrap_id}"

  echo """\
    >>> Bootstrap nodes: "spacemesh://${bootstrap_id}@${bootstrap_addr}:${config.port}",
    >>> PoET --nodeaddr: ${bootstrap_addr}:${bootstrap_grpc_port}
    """.stripIndent()

  return [
    netaddr:  "spacemesh://${bootstrap_id}@${bootstrap_addr}:${config.port}",
    nodeaddr: "${bootstrap_addr}:${bootstrap_grpc_port}",
  ]
}

/* vim: set filetype=groovy ts=2 sw=2 et : */
