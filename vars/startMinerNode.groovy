/*
  Start TestNet Miner node in the region

  Example:

    startMinerNode aws_region: "us-east-1", pool_id: "test01", node_id: "node-0001", \
                   init_miner_image: "...", miner_image: "...", vol_size: "300", port: 65100, \
                   spacemesh_space: "1048576", cpu_limit: "1950m", cpu_requests: "1950m", \
                   grpc_port: 9091, params: []

*/

import static io.spacemesh.awsinfra.commons.*

def call(Map config) {
  /* Defaults */
  config = [miner_image: default_miner_image,
            init_miner_image: "spacemeshos/spacemeshos-miner-init:latest",
            cpu_requests: "1950m", cpu_limit: "1950m",
            grpc_port: 0, params: [],
            ] + config

  kubectl = "kubectl --context=miner-${config.aws_region}"
  worker_id = "${config.pool_id}-${config.node_id}"
  node = "miner-${worker_id}"
  params = """\"${config.params.join('", "')}\""""
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
                    miner-pool: \"${config.pool_id}\"
                    miner-node: ${config.node_id}
                spec:
                  storageClassName: gp2-delayed
                  accessModes: [ ReadWriteOnce ]
                  resources:
                    requests:
                      storage: ${config.vol_size}Gi
                ---
                apiVersion: apps/v1
                kind: Deployment
                metadata:
                  name: ${node}
                  labels:
                    app: miner
                    miner-pool: \"${config.pool_id}\"
                    miner-node: ${config.node_id}
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
                        miner-pool: \"${config.pool_id}\"
                        miner-node: ${config.node_id}
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
                          image: \"${config.init_miner_image}\"
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
                              value: \"${config.spacemesh_space}\"

                          volumeMounts:
                            - name: miner-storage
                              mountPath: /root

                      containers:
                        - name: default
                          image: \"${config.miner_image}\"
                          imagePullPolicy: "Always"

                          ports:
                            - protocol: TCP
                              containerPort: ${config.port}
                              hostPort: ${config.port}
                            - protocol: UDP
                              containerPort: ${config.port}
                              hostPort: ${config.port}
            """ + (config.grpc_port ? """\

                            - protocol: TCP
                              containerPort: ${config.grpc_port}

                          readinessProbe:
                            initialDelaySeconds: 10
                            failureThreshold: 30
                            tcpSocket:
                              port: ${config.grpc_port}
            """ : "") + """\

                          env:
                            - name: SPACEMESH_MINER_PORT
                              value: \"${config.port}\"

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
                                  "--post-space",  \"${config.spacemesh_space}\",
                                  "--test-mode",
                                  "--start-mining",
                                  ${params}
                                ]
                          resources:
                            limits:
                              cpu: ${config.cpu_limit}
                              memory: "2Gi"
                            requests:
                              cpu: ${config.cpu_requests ?: config.cpu_limit}
                              memory: "2Gi"
                          volumeMounts:
                            - name: miner-storage
                              mountPath: /root
            """).stripIndent()

  echo "Creating ${node}"
  sh """${kubectl} create --save-config -f ${node}-deploy.yml"""
}

/* vim: set filetype=groovy ts=2 sw=2 et : */
