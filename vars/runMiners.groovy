/*
  Start TestNet miner nodes in the region

  Example:

    @Library("spacemesh") _
    runMiners("us-east-1")
*/

import static io.spacemesh.awsinfra.commons.*

def call(String aws_region) {
  /* Pipeline global vars */
  miner_count = 0
  worker_ports = []
  bootnodes = ''
  extra_params = []
  poet_ips = []
  labels = []

  /*
    PIPELINE
   */
  pipeline {
    agent any

    options {
      buildDiscarder(logRotator(numToKeepStr: '10')) // Keep last 10 builds only
    }

    parameters {
      string name: 'MINER_COUNT', defaultValue: '0', trim: true, \
             description: 'Number of the miners to start'

      string name: 'POOL_ID', defaultValue: '', trim: true, \
             description: 'Miner pool id'

      string name: 'BOOTNODES', defaultValue: '', trim: true, \
             description: 'Bootstrap using these nodes'

      string name: 'MINER_IMAGE', defaultValue: default_miner_image, trim: true, \
             description: 'Image to use'

      string name: 'MINER_CPU', defaultValue: '2', trim: true, \
             description: 'Miner resoruce request for CPU cores'

      string name: 'MINER_MEM', defaultValue: '4Gi', trim: true, \
             description: 'Miner resoruce request for RAM'

      string name: 'SPACEMESH_SPACE',defaultValue: '256G', trim: true, \
             description: 'Init file space size. Appeng G for GiB, M for MiB'

      string name: 'SPACEMESH_VOL_SIZE', defaultValue: '300', trim: true, \
             description: 'Miner job volume space, in GB'

      string name: 'EXTRA_PARAMS', defaultValue: '', trim: true, \
             description: 'Extra parameters to miner'
             
      string name: 'POET_IPS', defaultValue: '', trim: true, \
             description: 'Poet addresses'

      string name: 'LABELS', defaultValue: '', trim: true, \
             description: 'List of key=value miner labels (separated by whitespaces)'
    }

    stages {
      stage("Prepare") {
        steps {
          cleanWs()

          script {
            miner_count = params.MINER_COUNT as int
            vol_size = params.SPACEMESH_VOL_SIZE as int

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

            pool_id = params.POOL_ID ?: random_id()
            run_id = random_id()

            if(params.EXTRA_PARAMS) {
              extra_params = params.EXTRA_PARAMS.tokenize()
            }

            if(params.POET_IPS) {
              poet_ips = params.POET_IPS.tokenize()
            }

            if(params.BOOTNODES) {
              extra_params += ["--bootstrap", "--bootnodes", params.BOOTNODES]
            }

            worker_ports = random_ports(miner_count)
            worker_ports.sort()

            assert vol_size > 0
            assert miner_count > 0
            assert poet_ips.size() > 0
          }
          echo "Number of miners: ${miner_count}"
          echo "Miner pool ID: ${pool_id}"
          echo "Miner ports: ${worker_ports}"
          echo "Extra miner params: ${extra_params}"
        }
      }

      stage("Create workers") {
        steps {
          script {
            p = poet_ips.size()
            def builders = [:]
            worker_ports.eachWithIndex({port, i ->
              builders[port] = {->
                startMiner([aws_region: aws_region, pool_id: pool_id, node_id: "${run_id}-node-${port}", \
                               miner_image: params.MINER_IMAGE, port: port, \
                               spacemesh_space: SPACEMESH_SPACE, vol_size: vol_size, \
                               cpu: params.MINER_CPU, mem: params.MINER_MEM, \
                               params: extra_params, \
                               poet_ip: poet_ips[port%p], \
                               labels: params.LABELS])
              }
            })
            parallel builders
          }
        }
      }
    }
  }
}

def random_ports(int ctr, int low=62000, int high=65535) {
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

def startMiner(Map config) {
  /* Defaults */
  def c = [miner_image: default_miner_image,
            init_miner_image: "spacemeshos/spacemeshos-miner-init:latest",
            cpu: "2", mem: "4Gi",
            params: [],
            ] + config

  def kubectl = "kubectl --context=miner-${c.aws_region}"
  def node_id = c.node_id
  def port = c.port
  def worker_id = "${c.pool_id}-${node_id}"
  def node = "miner-${worker_id}"
  def params = """\"${c.params.join('", "')}\""""
  echo "Writing manifest for ${node}"
  writeFile file: "${node}-deploy.yml", \
            text: ("""\
                ---
                apiVersion: v1
                kind: PersistentVolumeClaim
                metadata:
                  name: ${node}
                  labels:
                    app: miner
                    miner-pool: \"${c.pool_id}\"
                    miner-node: ${node_id}
                spec:
                  storageClassName: gp2-delayed
                  accessModes: [ ReadWriteOnce ]
                  resources:
                    requests:
                      storage: ${c.vol_size}Gi
                ---
                apiVersion: apps/v1
                kind: Deployment
                metadata:
                  name: ${node}
                  labels:
                    app: miner
                    miner-pool: \"${c.pool_id}\"
                    miner-node: ${node_id}
                spec:
                  replicas: 1
                  selector:
                    matchLabels:
                      app: miner
                  strategy:
                    type: Recreate
                  template:
                    metadata:
                      labels:
                        app: miner
                        miner-pool: \"${c.pool_id}\"
                        miner-node: ${node_id}
                        worker-id:  \"${worker_id}\"
                    spec:
                      nodeSelector:
                        pool: miner
                      tolerations:
                        - key: dedicated
                          operator: Equal
                          value: miner
                          effect: NoSchedule
                      volumes:
                        - name: miner-storage
                          persistentVolumeClaim:
                            claimName: ${node}

                      initContainers:
                        - name: miner-init
                          image: \"${c.init_miner_image}\"
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
                              value: \"${worker_id}\"
                            - name: SPACEMESH_WORKDIR
                              value: "/root"
                            - name: SPACEMESH_DATADIR
                              value: "./post/data"
                            - name: SPACEMESH_SPACE
                              value: \"${c.spacemesh_space}\"

                          volumeMounts:
                            - name: miner-storage
                              mountPath: /root

                      containers:
                        - name: default
                          image: \"${c.miner_image}\"
                          imagePullPolicy: "Always"

                          ports:
                            - protocol: TCP
                              containerPort: ${port}
                              hostPort: ${port}
                            - protocol: UDP
                              containerPort: ${port}
                              hostPort: ${port}

                          env:
                            - name: SPACEMESH_MINER_PORT
                              value: \"${port}\"

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
                                  "--executable-path", "/bin/go-spacemesh",
                                  "--tcp-port",    \$(SPACEMESH_MINER_PORT),
                                  "--coinbase",    \$(SPACEMESH_COINBASE),
                                  "--poet-server", "${c.poet_ip}:8080",
                                  "--post-space",  "${c.spacemesh_space}",
                                  "--metrics-port", "2020",
                                  "--metrics",
                                  "--grpc-server",
                                  "--grpc-port", "9091",
                                  "--json-server",
                                  "--test-mode",
                                  "--start-mining",
                                  ${params}
                                ]
                          resources:
                            limits:
                              cpu: ${c.cpu}
                              memory: ${c.mem}
                            requests:
                              cpu: ${c.cpu}
                              memory: ${c.mem}
                          volumeMounts:
                            - name: miner-storage
                              mountPath: /root
            """).stripIndent()

  echo "Creating ${node}"
  sh """${kubectl} create --save-config -f ${node}-deploy.yml"""
  (pod_name, node_name) = shell("""\
    ${kubectl} wait pod -l worker-id=${worker_id} --for=condition=ready --timeout=360s \
    -o 'jsonpath={.metadata.name} {.spec.nodeName}'""").tokenize()
  miner_ext_ip = shell("""\
    ${kubectl} get node ${node_name} \
    -o 'jsonpath={.status.addresses[?(@.type=="ExternalIP")].address}'""")
  timeout(1) {
    waitUntil {
      script {
        miner_id = sh script: """${kubectl} exec ${pod_name} -- ls /root/spacemesh/p2p/nodes 2>/dev/null""", returnStatus: true
        return (miner_id.size() > 0)
      }
    }
  }

  shell("""${kubectl} label --overwrite pods ${pod_name} miner-id=${miner_id} miner-ext-ip=${miner_ext_ip} miner-ext-port=${port} ${c.labels}""")
  spacemesh_url = """spacemesh://${miner_id}@${miner_ext_ip}:${port}"""
  return spacemesh_url
}

/* vim: set filetype=groovy ts=2 sw=2 et : */
