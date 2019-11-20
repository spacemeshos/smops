/*
  Start TestNet

  Example:

    @Library("spacemesh") _
    startNetwork()
*/

import static io.spacemesh.awsinfra.commons.*

def call(String aws_region) {
  /* Defaults */

  kubectl_poet = "kubectl --context=${poet_ctx}"

  /* Pipeline global vars */
  poet_params = []
  miner_count = [:]
  worker_ports = []
  bootnode = [:]
  extra_params = []
  bootstrap_extra_params = []

  /*
    PIPELINE
   */
  pipeline {
    agent any

    options {
      buildDiscarder(logRotator(numToKeepStr: '10')) // Keep last 10 builds only
    }

    parameters {
      choice name: 'BOOT_REGION', choices: aws_regions, \
             description: "Region to run the bootstrap node at"

      string name: 'POET_IMAGE', defaultValue: default_poet_image, trim: true, \
             description: 'Container image to use for PoET'
      string name: 'POET_PARAMS', defaultValue: "", trim: true, \
             description: 'PoET parameters'

      /* FIXME: Move these to the seed job to be scriptable */
      string name: 'MINER_COUNT[ap-northeast-2]', defaultValue: '0', trim: true, \
             description: 'Number of the miners to start in ap-northeast-2'
      string name: 'MINER_COUNT[eu-north-1]', defaultValue: '0', trim: true, \
             description: 'Number of the miners to start in eu-north-1'
      string name: 'MINER_COUNT[us-east-1]', defaultValue: '0', trim: true, \
             description: 'Number of the miners to start in us-east-1'
      string name: 'MINER_COUNT[us-east-2]', defaultValue: '0', trim: true, \
             description: 'Number of the miners to start in us-east-2'
      string name: 'MINER_COUNT[us-west-2]', defaultValue: '0', trim: true, \
             description: 'Number of the miners to start in us-west-2'

      string name: 'MINER_IMAGE', defaultValue: default_miner_image, trim: true, \
             description: 'Image to use'

      string name: 'GENESIS_TIME', defaultValue: '', trim: true, \
             description: 'Genesis time'

      string name: 'GENESIS_DELAY', defaultValue: '60', trim: true, \
             description: 'Genesis delay from now, minutes'

      string name: 'SPACEMESH_SPACE',defaultValue: '256G', trim: true, \
             description: 'Init file space size. Appeng G for GiB, M for MiB'

      string name: 'SPACEMESH_VOL_SIZE', defaultValue: '300', trim: true, \
             description: 'Miner job volume space, in GB'

      string name: 'EXTRA_PARAMS', defaultValue: '', trim: true, \
             description: 'Extra parameters to miner node'

      string name: 'BOOTSTRAP_EXTRA_PARAMS', defaultValue: '', trim: true, \
             description: 'Extra parameters to bootstrap node (leave blank if the same as miner)'
    }

    stages {
      stage("Prepare") {
        steps {
          cleanWs()

          script {
            assert params.BOOT_REGION in aws_regions

            vol_size = params.SPACEMESH_VOL_SIZE as int
            assert vol_size > 0

            aws_regions.each {region->
              miner_count[region] = params.getOrDefault("MINER_COUNT[${region}]" as String, "0") as int
            }
            assert miner_count.values().sum() > 0

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

            if(params.EXTRA_PARAMS) {
              extra_params = params.EXTRA_PARAMS.tokenize()
              bootstrap_extra_params = extra_params
            }
            if(params.BOOTSTRAP_EXTRA_PARAMS) {
              bootstrap_extra_params = params.BOOTSTRAP_EXTRA_PARAMS.tokenize()
            }

            def genesis_time = ""

            if(params.GENESIS_TIME) {
              genesis_time = params.GENESIS_TIME
            } else if(params.GENESIS_DELAY) {
              genesis_time = (new Date(currentBuild.startTimeInMillis + (params.GENESIS_DELAY as int)*60*1000)).format("yyyy-MM-dd'T'HH:mm:ss'+00:00'")
            }

            if(genesis_time) {
              extra_params += ["--genesis-time", genesis_time]
              bootstrap_extra_params += ["--genesis-time", genesis_time]
            }

            if(params.POET_PARAMS) {
              poet_params = params.POET_PARAMS.tokenize()
            }

            bootstrap_port = random_port()
          }

          echo " >>> Number of miners: ${miner_count}"
          echo " >>> Miner pool ID: ${pool_id}"
          echo " >>> Miner ports: ${worker_ports}"
          echo " >>> Extra miner params: ${extra_params}"
          echo " >>> Bootstrap node port: ${bootstrap_port}"
          echo " >>> Extra bootstrap params: ${bootstrap_extra_params}"
        }
      }

      stage("Start PoET") {
        steps {
          startPoET image: params.POET_IMAGE, params: poet_params
        }
      }

      stage("Start bootstrap node") {
        steps {
          script {
            bootnode = startBootstrapNode(aws_region: params.BOOT_REGION, pool_id: pool_id, \
                                          miner_image: params.MINER_IMAGE, port: bootstrap_port, \
                                          vol_size: vol_size, spacemesh_space: SPACEMESH_SPACE, \
                                          params: bootstrap_extra_params, \
                                          )
          }

          echo " >>> Bootnodes: ${bootnode.netaddr}"
          echo " >>> PoET nodeAddress: ${bootnode.nodeaddr}"
        }
      }

      stage("Update PoET config") {
        steps {
          echo "Getting PoET podIP"
          retry(5) {
            script {
              poet_ip = shell("""${kubectl_poet} get pod -l app=poet --template '{{(index .items 0).status.podIP}}'""")
              if(! poet_ip) {
                error "No podIP for app=poet"
              }
            }
          }
          echo "Invoking start_mining at '${poet_ip}'"
          sh """curl -is --data '{"nodeAddress": "${bootnode.nodeaddr}"}' http://${poet_ip}:8080/v1/start"""
        }
      }

      stage("Create workers") {
        steps {
          script {
            stages = [:]
            aws_regions.each {region->
              if(miner_count[region]) {
                stages[region] = {->
                  build job: "./${region}/run-miners", parameters: [
                            string(name: 'MINER_COUNT', value: miner_count[region] as String),
                            string(name: 'POOL_ID', value: pool_id),
                            string(name: 'BOOTNODES', value: bootnode.netaddr),
                            string(name: 'MINER_IMAGE', value: params.MINER_IMAGE),
                            string(name: 'GENESIS_TIME', value: ''),
                            string(name: 'GENESIS_DELAY', value: ''),
                            string(name: 'SPACEMESH_SPACE', value: SPACEMESH_SPACE as String),
                            string(name: 'SPACEMESH_VOL_SIZE', value: vol_size as String),
                            string(name: 'EXTRA_PARAMS', value: extra_params.join(" ")),
                          ], propagate: false
                }
              }
            }
            parallel stages
          }
        }
      }

      stage("Archive artifacts") {
        steps {
          archiveArtifacts "poet-deploy.yml, miner-*-bootstrap-svc.yml, miner-*-bootstrap-deploy.yml"
        }
      }
    }
  }
}

def random_port(int low=61000, int high=65535) {
  (low + (high-low)*(new Random()).nextFloat()) as int
}

/* vim: set filetype=groovy ts=2 sw=2 et : */
