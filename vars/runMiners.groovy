def random_ports(int ctr, int low=61000, int high=65535) {
  def rnd = new Random()
  def rand_port = {-> (low + (high-low)*rnd.nextFloat()) as int }

  def ports = []
  (1..ctr).each({
    def r = rand_port()
    while(r in ports)
      r = rand_port()
    ports << r
  })

  return ports
}

def call(aws_region="us-east-2") {
  kubectl      = "kubectl --context=miner-${aws_region}"
  kubectl_poet = "kubectl --context=initfactory-${aws_region}"

  default_miner_image = "spacemeshos/go-spacemesh:develop"
  init_miner_image    = "534354616613.dkr.ecr.us-east-1.amazonaws.com/spacemesh-testnet-miner-init:latest"

  /* Pipeline global vars */
  miner_count = 0
  worker_ports = []
  bootstrap_addr = ""
  bootstrap_pod = ""
  bootstrap_tcp_port = ""
  bootstrap_grpc_port = ""
  bootstrap_id = ""
  bootnodes = ""
  extra_params = ""
  bootstrap_extra_params = ""
  node_cpu_requests = "1950m"
  node_cpu_limit    = "1950m"

  /* Library function: generate random hex string */
  random_id = {->
    def rnd = new Random()
    return {-> String.format("%06x",(rnd.nextFloat() * 2**31) as Integer)[0..5]}
  }()

  create_service = {svc, pool_id, node, proto, port ->
    echo "Writing service manifest for ${svc}"
    writeFile file: "${svc}-svc.yml", text: """\
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: ${svc}
      labels:
        app: miner
        miner-pool: \"${pool_id}\"
    spec:
      type: NodePort
      selector:
        miner-node: \"${node}\"
      ports:
      - protocol: ${proto.toUpperCase()}
        port: ${port}
    """.stripIndent()

    echo "Creating service ${svc}"
    sh """${kubectl} create -f ${svc}-svc.yml"""
  }

  get_bootstrap_pod = {pool_id ->
    """\
    ${kubectl} get pod -l miner-node=miner-${pool_id}-bootstrap --template '{{\$i := index .items 0 }}{{\$i.metadata.name}} {{\$i.status.phase}} {{\$i.spec.nodeName}}' 2>/dev/null
    """.stripIndent().trim()
  }

  worker_manifest = {pool_id, miner_name, miner_port, miner_image, miner_params ->
    """\
    ---
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: miner-${pool_id}-pvc-${miner_name}
      labels:
        app: miner
        miner-pool: \"${pool_id}\"
        miner-node: miner-${pool_id}-${miner_name}
    spec:
      storageClassName: gp2-delayed
      accessModes: [ ReadWriteOnce ]
      resources:
        requests:
          storage: ${SPACEMESH_VOL_SIZE}Gi
    ---
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: miner-${pool_id}-${miner_name}
      labels:
        app: miner
        miner-pool: \"${pool_id}\"
        miner-node: miner-${pool_id}-${miner_name}
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: miner
      template:
        metadata:
          labels:
            app: miner
            miner-pool: \"${pool_id}\"
            miner-node: miner-${pool_id}-${miner_name}
        spec:
          nodeSelector:
            pool: miner
          tolerations:
            - key: dedicated
              operator: Equal
              value: miner
              effect: NoExecute
          volumes:
            - name: miner-storage
              persistentVolumeClaim:
                claimName: miner-${pool_id}-pvc-${miner_name}

          initContainers:
            - name: miner-init
              image: \"${init_miner_image}\"
              env:
                - name: SPACEMESH_S3_BUCKET
                  valueFrom:
                    configMapKeyRef:
                      name: initfactory
                      key: initdata_s3_bucket
                - name: SPACEMESH_S3_PREFIX
                  valueFrom:
                    configMapKeyRef:
                      name: initfactory
                      key: initdata_s3_prefix
                - name: SPACEMESH_DYNAMODB_TABLE
                  valueFrom:
                    configMapKeyRef:
                      name: initfactory
                      key: initdata_dynamodb_table
                - name: SPACEMESH_DYNAMODB_REGION
                  valueFrom:
                    configMapKeyRef:
                      name: initfactory
                      key: initdata_dynamodb_region
                - name: SPACEMESH_WORKER_ID
                  valueFrom:
                    fieldRef:
                      fieldPath: metadata.name
                - name: SPACEMESH_WORKDIR
                  value: "/root"
                - name: SPACEMESH_DATADIR
                  value: "./post/data"
                - name: SPACEMESH_SPACE
                  value: \"${SPACEMESH_SPACE}\"

              volumeMounts:
                - name: miner-storage
                  mountPath: /root

          containers:
            - name: default
              image: \"${miner_image}\"
              imagePullPolicy: "Always"

              ports:
                - protocol: TCP
                  containerPort: ${miner_port}
                  hostPort: ${miner_port}
                - protocol: UDP
                  containerPort: ${miner_port}
                  hostPort: ${miner_port}

              env:
                - name: SPACEMESH_MINER_PORT
                  value: \"${miner_port}\"
                - name: SPACEMESH_GRPC_PORT
                  value: \"${miner_port}\"
                - name: SPACEMESH_COINBASE
                  valueFrom:
                    configMapKeyRef:
                      name: initfactory
                      key: spacemesh_coinbase
                - name: SPACEMESH_POET_GRPC
                  valueFrom:
                    configMapKeyRef:
                      name: initfactory
                      key: poet_url

              args: [ "--config", "/root/config.toml",
                      "--tcp-port",    \$(SPACEMESH_MINER_PORT),
                      "--coinbase",    \$(SPACEMESH_COINBASE),
                      "--poet-server", \$(SPACEMESH_POET_GRPC),
                      "--genesis-time", \"${SPACEMESH_GENESIS_TIME}\",
                    ]
              resources:
                limits:
                  cpu: ${node_cpu_limit}
                requests:
                  cpu: ${node_cpu_requests}
              volumeMounts:
                - name: miner-storage
                  mountPath: /root
    """.stripIndent()
  }

  get_node_inst_id = {node ->
    """\
    ${kubectl} get node ${node} --template '{{.spec.providerID}}' | sed -e 's/.\\+\\///'
    """.stripIndent()
  }

  get_instance_ip = {inst_id ->
    """\
    aws ec2 describe-instances --region=${aws_region} --instance-ids ${inst_id} --query 'Reservations[0].Instances[0].PublicIpAddress' --output text
    """.stripIndent()
  }

  get_bootstrap_id = {pod ->
    """\
    ${kubectl} logs ${pod} --tail=-1 -f |\\
    sed -ne '/Local node identity / { s/.\\+Local node identity >> \\([a-zA-Z0-9]\\+\\).*/\\1/ ; p; q; }'
    """.stripIndent()
  }

  /*
    PIPELINE
   */
  pipeline {
    agent any

    options {
      buildDiscarder(logRotator(numToKeepStr: '10')) // Keep last 10 builds only
    }

    parameters {
      string name: 'MINER_COUNT', defaultValue: '0', description: 'Number of the miners to start', trim: true
      string name: 'MINER_IMAGE', defaultValue: default_miner_image, description: 'Miner pool id', trim: true
      string name: 'POOL_ID',     defaultValue: '', description: 'Miner pool id', trim: true
      string name: 'GENESIS_TIME',  defaultValue: '', description: 'Genesis time', trim: true
      string name: 'GENESIS_DELAY', defaultValue: '5', description: 'Genesis delay from now, minutes', trim: true
      string name: 'SPACEMESH_SPACE',    defaultValue: '1048576', description: 'Init file space size. Appeng G for GiB, M for MiB'
      string name: 'SPACEMESH_VOL_SIZE', defaultValue: '10', description: 'Miner job volume space, in GB'
      string name: 'EXTRA_PARAMS',           defaultValue: '', description: 'Extra parameters to miner'
      string name: 'BOOTSTRAP_EXTRA_PARAMS', defaultValue: '',\
             description: 'Extra parameters to bootstrap node (leave blank if the same as miner)'
    }

    stages {
      stage("Prepare") {
        steps {
          cleanWs()

          script {
            miner_count = params.MINER_COUNT as int
            SPACEMESH_VOL_SIZE = SPACEMESH_VOL_SIZE as int

            if(params.SPACEMESH_SPACE) {
              if(params.SPACEMESH_SPACE.endsWith("G")) {
                SPACEMESH_SPACE = (params.SPACEMESH_SPACE[0..-2] as long) * (1024L**3)
              } else if(params.SPACEMESH_SPACE.endsWith("M")) {
                SPACEMESH_SPACE = (params.SPACEMESH_SPACE[0..-2] as long) * (1024L**2)
              } else {
                SPACEMESH_SPACE = (params.SPACEMESH_SPACE as long)
              }
            } else {
              /* Reset to 0 if not specified */
              SPACEMESH_SPACE = 0
            }

            assert SPACEMESH_VOL_SIZE >= 1
            assert miner_count > 0

            SPACEMESH_GENESIS_TIME = params.GENESIS_TIME ?: (new Date(currentBuild.startTimeInMillis + (params.GENESIS_DELAY as int)*60*1000)).format("yyyy-MM-dd'T'HH:mm:ss'+00:00'")

            pool_id = params.POOL_ID ?: random_id()
            worker_ports = random_ports(miner_count + 1)
            bootstrap_tcp_port = worker_ports.pop()
            worker_ports.sort()

            if(params.EXTRA_PARAMS.trim()) {
              extra_params = '"' + params.EXTRA_PARAMS.trim().tokenize().join('", "') + '"'
              bootstrap_extra_params = extra_params
            }
            if(params.BOOTSTRAP_EXTRA_PARAMS.trim()) {
              bootstrap_extra_params = '"' + params.BOOTSTRAP_EXTRA_PARAMS.trim().tokenize().join('", "') + '"'
            }
          }
          echo "Number of miners: ${miner_count}"
          echo "Miner pool ID: ${pool_id}"
          echo "Bootstrap port: ${bootstrap_tcp_port}"
          echo "Miner ports: ${worker_ports}"
          echo "Extra miner params: ${extra_params}"
          echo "Extra bootstrap params: ${bootstrap_extra_params}"
        }
      }

      stage("Create bootstrap gRPC service") {
        steps {
          script {
            def boot_node = "miner-${pool_id}-bootstrap"
            create_service("${boot_node}-grpc", pool_id, boot_node, "TCP", 9091)

            echo "Getting allocated port"
            bootstrap_grpc_port = shell("""\
              ${kubectl} get svc ${boot_node}-grpc --template '{{(index .spec.ports 0).nodePort}}'""")
          }

          echo "Bootstrap GRPC port: ${bootstrap_grpc_port}"
        }
      }

      stage("Create bootstrap miner") {
        steps {
          echo "Generating manifest"
          writeFile file: "bootstrap-${pool_id}-deploy.yml",
                    text: worker_manifest(pool_id, "bootstrap", bootstrap_grpc_port, params.MINER_IMAGE, """\
                                          "--grpc-server", "--grpc-port", \$(SPACEMESH_GRPC_PORT), ${bootstrap_extra_params}
                                          """.stripIndent(),
                                          )

          echo "Creating bootstrap Deployment"
          sh """${kubectl} create -f bootstrap-${pool_id}-deploy.yml"""

          echo "Waiting for the bootstrap pod to be scheduled..."
          sh """${kubectl} wait --timeout=600s --for=condition=Available deploy/miner-${pool_id}-bootstrap"""

          script {
            def pod_node

            (bootstrap_pod, pod_status, pod_node) = shell(get_bootstrap_pod(pool_id)).split()

            echo "Running on node ${pod_node}, getting AWS instance id"
            def inst_id = shell(get_node_inst_id(pod_node))

            echo "Getting AWS instance '${inst_id}' public IP"
            bootstrap_addr = shell(get_instance_ip(inst_id))
          }
          echo "Bootstrapping from: ${bootstrap_addr}:${bootstrap_tcp_port}"

          echo "Getting bootstrap miner_id from the logs"
          script {
            timeout(time: 600, unit: 'SECONDS') {
              bootstrap_id = shell(get_bootstrap_id(bootstrap_pod))
            }
          }
          echo "Bootstrap ID: ${bootstrap_id}"

          script {
            bootnodes = "spacemesh://${bootstrap_id}@${bootstrap_addr}:${bootstrap_tcp_port}"
          }

          echo """\
            >>> Genesis time: ${SPACEMESH_GENESIS_TIME}
            >>> Bootstrap nodes: ${bootnodes}
            >>> PoET --nodeaddr: ${bootstrap_addr}:${bootstrap_grpc_port}
            """.stripIndent()
        }
      }

      stage("Update PoET config") {
        steps {
          echo "Setting PoET --nodeaddr"
          sh """${kubectl_poet} patch configmap initfactory -p '{"data":{"poet_nodeaddr":"${bootstrap_addr}:${bootstrap_grpc_port}"}}'"""

          echo "PoET pods before"
          sh """${kubectl_poet} get pod -l app=poet"""
          echo "Restarting PoET"
          sh """${kubectl_poet} delete pod -l app=poet"""
          sleep 5
          echo "PoET pods after"
          sh """${kubectl_poet} get pod -l app=poet"""
        }
      }

      stage("Create workers") {
        steps {
          script {
            worker_ports.eachWithIndex({port, i ->
              i++
              def i_str = String.format("%04d", i)
              echo "Generating manifest for worker #${i}"
              writeFile file: "miner-${pool_id}-node-${i_str}-deploy.yml", \
                        text: worker_manifest(pool_id, "node-${i_str}", port, params.MINER_IMAGE, """\
                                                "--bootstrap", "--bootnodes", \"${bootnodes}\", ${extra_params}
                                              """.stripIndent(),
                                              )
              echo "Creating Deployment for worker #${i}"
              sh """${kubectl} create -f miner-${pool_id}-node-${i_str}-deploy.yml"""
            })
          }
        }
      }

      stage("Archive artifacts") {
        steps {
          archiveArtifacts "miner-*-bootstrap-grpc-svc.yml, bootstrap-*-deploy.yml, miner-*-node-0001-deploy.yml"
        }
      }
    }
  }
}

/* vim: set filetype=groovy ts=2 sw=2 et : */
