/*
  Start TestNet Miner node in the region

  Example:

    startMinerNode aws_region: "us-east-1", pool_id: "test01", node_id: "node-0001", \
                   init_miner_image: "...", miner_image: "...", vol_size: "300", port: 65100, \
                   spacemesh_space: "1048576", cpu_limit: "1950m", cpu_requests: "1950m", \
                   params: []

*/

def call(Map config) {
  /* Defaults */
  config = [miner_image: "spacemeshos/go-spacemesh:develop",
            init_miner_image: "534354616613.dkr.ecr.us-east-1.amazonaws.com/spacemesh-testnet-miner-init:latest",
            cpu_requests: "1950m", cpu_limit: "1950m",
            params: [],
            ] + config

  kubectl = "kubectl --context=miner-${config.aws_region}"

  node = "miner-${config.pool_id}-${config.node_id}"
  params = """\"${config.params.join('", "')}\""""
  echo "Writing manifest for ${node}"
  writeFile file: "${node}-deploy.yml", \
            text: """\
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
                  template:
                    metadata:
                      labels:
                        app: miner
                        miner-pool: \"${config.pool_id}\"
                        miner-node: ${config.node_id}
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
                              valueFrom:
                                fieldRef:
                                  fieldPath: metadata.name
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
                                  ${params},
                                ]
                          resources:
                            limits:
                              cpu: ${config.cpu_limit}
                            requests:
                              cpu: ${config.cpu_requests ?: config.cpu_limit}
                          volumeMounts:
                            - name: miner-storage
                              mountPath: /root
            """.stripIndent()

  echo "Creating ${node}"
  sh """${kubectl} create -f ${node}-deploy.yml"""
}

/* vim: set filetype=groovy ts=2 sw=2 et : */
