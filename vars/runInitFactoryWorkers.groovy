def call(aws_region="us-east-2") {
  /* kubectl command */
  def kubectl = "kubectl --context=initfactory-${aws_region}"

  /* Container image to use */
  def initfactory_image = "534354616613.dkr.ecr.us-east-1.amazonaws.com/spacemesh-testnet-initfactory:latest"

  /* Job resources and other params */
  def backoff_limit = 20
  def cpu_requests  = "1950m"
  def cpu_limits    = "1950m"

  /* Pipeline global vars */
  def job_id

  /*
    PIPELINE
   */
  pipeline {
    options {
      buildDiscarder(logRotator(numToKeepStr: '5')) // Keep last 5 builds only
    }

    /* Job parameters */
    parameters {
      string name: 'INIT_COUNT',         defaultValue: '10',      description: 'Init tasks(jobs) count'
      string name: 'SPACEMESH_SPACE',    defaultValue: '1048576', description: 'Init file space size. Appeng G for GiB, M for MiB'
      string name: 'SPACEMESH_VOL_SIZE', defaultValue: '10',      description: 'Init job volume space'
      string name: 'SPACEMESH_ID',       defaultValue: '',        description: 'Miner ID'
    }

    agent any

    stages {
      stage("Prepare") {
        steps {
          script {
            // Ensure the parameters are numeric
            INIT_COUNT = params.INIT_COUNT as int
            SPACEMESH_VOL_SIZE = params.SPACEMESH_VOL_SIZE as int

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

            assert SPACEMESH_VOL_SIZE > 0

            SPACEMESH_ID = params.SPACEMESH_ID ?: ""
            // If miner ID is given - then run a single job
            if(SPACEMESH_ID != "") {
                INIT_COUNT = 1
            }

            // Generate a random job id
            job_id = String.format("%08x", (new Random()).nextInt())
          }
        }
      }

      stage('Create k8s manifest') {
        steps {
          script {
            (1..INIT_COUNT).collect().each({i ->
              i = String.format("%04d", i)
              k8s_manifest = """\
                ---
                apiVersion: v1
                kind: PersistentVolumeClaim
                metadata:
                  name: initfactory-${job_id}-pvc-${i}
                  labels:
                    app: initfactory
                    init-job: \"${job_id}\"
                    worker-id: initfactory-${job_id}-job-${i}
                spec:
                  storageClassName: gp2-delayed
                  accessModes: [ ReadWriteOnce ]
                  resources:
                    requests:
                      storage: ${SPACEMESH_VOL_SIZE}Gi
                ---
                apiVersion: batch/v1
                kind: Job
                metadata:
                  name: initfactory-${job_id}-job-${i}
                  labels:
                    app: initfactory
                    init-job: \"${job_id}\"
                    worker-id: initfactory-${job_id}-job-${i}
                spec:
                  template:
                    metadata:
                      labels:
                        app: initfactory
                    spec:
                      tolerations:
                        - effect: NoExecute
                          key: dedicated
                          operator: Equal
                          value: initfactory
                      nodeSelector:
                        pool: initfactory
                      volumes:
                        - name: data-storage
                          persistentVolumeClaim:
                            claimName: initfactory-${job_id}-pvc-${i}
                      initContainers:
                        - name: init
                          image: alpine:3.10.1
                          volumeMounts:
                            - mountPath: /home
                              name: data-storage
                          command: [ /bin/sh, -c, "adduser -D spacemesh" ]
                      containers:
                        - name: default
                          image: "${initfactory_image}"
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
                            - name: SPACEMESH_SPACE
                              value: "${SPACEMESH_SPACE}"
                            - name: SPACEMESH_ID
                              value: "${SPACEMESH_ID}"
                          volumeMounts:
                            - mountPath: /home
                              name: data-storage
                          resources:
                            requests:
                              cpu: "${cpu_requests}"
                            limits:
                              cpu: "${cpu_limits}"
                      restartPolicy: OnFailure
                  backoffLimit: ${backoff_limit}
                """.stripIndent()
              writeFile file: "initfactory-${job_id}-job-${i}.yml", text: k8s_manifest
            })
          }
        }
      }

      stage('Apply manifest') {
        steps {
          script {
            (1..INIT_COUNT).collect().each({i ->
              i = String.format("%04d", i)
              sh """${kubectl} apply -f initfactory-${job_id}-job-${i}.yml"""
            })
          }
        }
      }

      stage('Archive manifest') {
        steps {
          archiveArtifacts "initfactory-${job_id}-job-0001.yml"
        }
      }
    }

    post {
      success {
        // Do some cleanup
        sh "rm -f manifest-*.yml"
      }
    }
  }
}

/* vim:set filetype=groovy ts=2 sw=2 et: */
