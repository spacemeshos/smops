/*
  Start TestNet Miner node in the region
*/

import static io.spacemesh.awsinfra.commons.*

def call(Map config) {
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
                        - name: config-map
                          configMap:
                            name: miner-files

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
                            - protocol: TCP
                              containerPort: 9091
                            - protocol: TCP
                              containerPort: 9090
                          readinessProbe:
                            initialDelaySeconds: 10
                            failureThreshold: 30
                            tcpSocket:
                              port: 9091

                          env:
                            - name: SPACEMESH_MINER_PORT
                              value: \"${port}\"

                          args: [ "--config", "/root/config.toml",
                                  "--executable-path", "/bin/go-spacemesh",
                                  "--test-mode",
                                  "--grpc-server",
                                  "--json-server",
                                  "--metrics-port", "2020",
                                  "--metrics",
                                  "--start-mining",
                                  "--coinbase",     "910d30bfb6b29577ed130e3fdc27a1cabd639f46ac93831de14279c444b9ef0b",
                                  "--tcp-port",    \$(SPACEMESH_MINER_PORT)
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
                            - name: config-map
                              mountPath: /root/config.toml
                              subPath: config.toml
            """).stripIndent()

  echo "Creating ${node}"
  sh """${kubectl} create --save-config -f ${node}-deploy.yml"""
  def (pod_name, node_name) = shell("""\
    ${kubectl} wait pod -l worker-id=${worker_id} --for=condition=ready --timeout=360s \
    -o 'jsonpath={.metadata.name} {.spec.nodeName}'""").tokenize()
  def miner_ext_ip = shell("""\
    ${kubectl} get node ${node_name} \
    -o 'jsonpath={.status.addresses[?(@.type=="ExternalIP")].address}'""")
  def miner_id = ''
  timeout(1) {
    waitUntil {
      script {
        miner_id = shell("""${kubectl} exec ${pod_name} -- /bin/sh -c '[ -d /root/spacemesh/p2p/nodes ] && ls /root/spacemesh/p2p/nodes || echo'""")
        return (miner_id.size() > 0)
      }
    }
  }

  shell("""${kubectl} label --overwrite pods ${pod_name} miner-id=${miner_id} miner-ext-ip=${miner_ext_ip} miner-ext-port=${port} ${c.labels}""")
  def spacemesh_url = """spacemesh://${miner_id}@${miner_ext_ip}:${port}"""
  return spacemesh_url
}

/* vim: set filetype=groovy ts=2 sw=2 et : */
