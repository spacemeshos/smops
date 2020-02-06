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
  poet_params = ''
  gateway_count = 0
  miner_count = [:]
  bootnodes = []
  extra_params = []

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
      string name: 'POET_N', defaultValue: '', trim: true, \
             description: 'PoET time parameter'
      string name: 'POET_DURATION', defaultValue: '', trim: true, \
             description: 'PoET round duration'
      string name: 'POET_COUNT', defaultValue: '1', trim: true, \
             description: 'Number of PoETs'
      string name: 'POET_INITIALDURATION', defaultValue: '', trim: true, \
             description: 'Initial round duration per PoET'

      string name: 'GATEWAY_MINER_COUNT', defaultValue: '1', trim: true, \
             description: 'Number of gateway miners (including bootstrap)'

      /* FIXME: Move these to the seed job to be scriptable */
      string name: 'MINER_COUNT[us-east-1]', defaultValue: '0', trim: true, \
             description: 'Number of the miners to start in us-east-1'
      string name: 'MINER_COUNT[us-east-2]', defaultValue: '0', trim: true, \
             description: 'Number of the miners to start in us-east-2'
      string name: 'MINER_COUNT[us-west-2]', defaultValue: '0', trim: true, \
             description: 'Number of the miners to start in us-west-2'
      string name: 'MINER_COUNT[ap-northeast-2]', defaultValue: '0', trim: true, \
             description: 'Number of the miners to start in ap-northeast-2'
      string name: 'MINER_COUNT[eu-north-1]', defaultValue: '0', trim: true, \
             description: 'Number of the miners to start in eu-north-1'

      string name: 'MINER_IMAGE', defaultValue: default_miner_image, trim: true, \
             description: 'Image to use'

      string name: 'MINER_CPU', defaultValue: '2', trim: true, \
             description: 'Miner resoruce request for CPU cores'

      string name: 'MINER_MEM', defaultValue: '4Gi', trim: true, \
             description: 'Miner resoruce request for RAM'

      string name: 'GENESIS_DELAY', defaultValue: '10', trim: true, \
             description: 'Genesis delay from now, minutes'

      string name: 'SPACEMESH_SPACE',defaultValue: '1M', trim: true, \
             description: 'Init file space size. Appeng G for GiB, M for MiB'

      string name: 'SPACEMESH_VOL_SIZE', defaultValue: '10', trim: true, \
             description: 'Miner job volume space, in GB'

      string name: 'EXTRA_PARAMS', defaultValue: '', trim: true, \
             description: 'Extra parameters to miner node'
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
            }

            assert (params.POET_N as Integer) > 0
            poet_params = "--n ${params.POET_N}"

            if(params.POET_DURATION) {
              poet_params += " --duration ${params.POET_DURATION}"
            }

            assert (params.POET_COUNT as Integer) > 0
            assert params.POET_INITIALDURATION.tokenize().size() == (params.POET_COUNT as Integer)

            gateway_count = (params.GATEWAY_MINER_COUNT as Integer) - 1
            assert gateway_count >= 0

            kubectl_boot = "kubectl --context=miner-${params.BOOT_REGION}"
          }

          echo " >>> Number of gateways/bootstraps: ${gateway_count + 1}"
          echo " >>> Total number of miners: ${miner_count}"
          echo " >>> Miner pool ID: ${pool_id}"
          echo " >>> Extra miner params: ${extra_params}"
        }
      }

      stage("Create PoETs") {
        steps {
          startPoET image: params.POET_IMAGE, count: params.POET_COUNT, params: poet_params, initialduration: params.POET_INITIALDURATION
          script {
            poet_ips = shell("""${kubectl_poet} get pod -l app=poet -o 'jsonpath={.items[*].status.podIP}'""")
            poet_ips = poet_ips.tokenize()
            echo "poet_ips: ${poet_ips}"
          }
        }
      }

      stage("Create gateways/bootstraps") {
        steps {
          script {
            echo "Initial gateway/bootstrap"


            genesis_time = (new Date(currentBuild.startTimeInMillis + (params.GENESIS_DELAY as int)*60*1000)).format("yyyy-MM-dd'T'HH:mm:ss'+00:00'")
            extra_params += ["--genesis-time", genesis_time]

            echo " >>> Genesis time: ${genesis_time}"
            
            spacemesh_url = 'spacemesh://{.metadata.labels.miner-id}@{.metadata.labels.miner-ext-ip}:{.metadata.labels.miner-ext-port}'
            
            runMinersJob = build job: "./${params.BOOT_REGION}/run-miners", parameters: [
              string(name: 'MINER_COUNT', value: '1'),
              string(name: 'POOL_ID', value: pool_id),
              string(name: 'BOOTNODES', value: ''),
              string(name: 'MINER_IMAGE', value: params.MINER_IMAGE),
              string(name: 'SPACEMESH_SPACE', value: SPACEMESH_SPACE as String),
              string(name: 'SPACEMESH_VOL_SIZE', value: vol_size as String),
              string(name: 'MINER_CPU', value: params.MINER_CPU as String),
              string(name: 'MINER_MEM', value: params.MINER_MEM as String),
              string(name: 'EXTRA_PARAMS', value: extra_params.join(" ")),
              string(name: 'POET_IPS', value: poet_ips.join(" ")),
              string(name: 'LABELS', value: 'miner-role=gateway'),
            ], propagate: true, wait: true

            boot_miner = shell("""\
              ${kubectl_boot} wait pod -l miner-role=gateway --for=condition=ready --timeout=360s \
              -o 'jsonpath=${spacemesh_url}'""")
            
            echo "boot_miner: $boot_miner"
            
            if(gateway_count) {
              echo "Extra gateways/bootstraps"
              runMinersJob = build job: "./${params.BOOT_REGION}/run-miners", parameters: [
                string(name: 'MINER_COUNT', value: gateway_count as String),
                string(name: 'POOL_ID', value: pool_id),
                string(name: 'BOOTNODES', value: boot_miner),
                string(name: 'MINER_IMAGE', value: params.MINER_IMAGE),
                string(name: 'SPACEMESH_SPACE', value: SPACEMESH_SPACE as String),
                string(name: 'SPACEMESH_VOL_SIZE', value: vol_size as String),
                string(name: 'MINER_CPU', value: params.MINER_CPU as String),
                string(name: 'MINER_MEM', value: params.MINER_MEM as String),
                string(name: 'EXTRA_PARAMS', value: extra_params.join(" ")),
                string(name: 'POET_IPS', value: poet_ips.join(" ")),
                string(name: 'LABELS', value: 'miner-role=gateway'),
              ], propagate: true, wait: true
            }

            bootnodes = shell("""\
              ${kubectl_boot} wait pod -l miner-role=gateway --for=condition=ready --timeout=360s \
              -o 'jsonpath=${spacemesh_url} '""").tokenize().join(',')

            echo "bootnodes: $bootnodes"
          }
        }
      }

      stage("Start PoETs") {
        steps {
          script {
            gateways = shell("""\
              ${kubectl_boot} wait pod -l miner-role=gateway --for=condition=ready --timeout=360s \
              -o 'jsonpath={.status.podIP}:9091 '""").tokenize()

            echo "gateways: $gateways"

            gateways_json = groovy.json.JsonOutput.toJson(gateways)
            poet_ips.each {poet_ip->
              sh """curl -is --data '{"gatewayAddresses": ${gateways_json}}' ${poet_ip}:8080/v1/start"""
            }
          }
        }
      }

      stage("Create genesis miners") {
        steps {
          script {
            increaseNetworkJob = build job: "./increase-network", parameters: [
              string(name: 'MINER_COUNT[us-east-1]', value: miner_count['us-east-1'] as String),
              string(name: 'MINER_COUNT[us-east-2]', value: miner_count['us-east-2'] as String),
              string(name: 'MINER_COUNT[us-west-2]', value: miner_count['us-west-2'] as String),
              string(name: 'MINER_COUNT[ap-northeast-2]', value: miner_count['ap-northeast-2'] as String),
              string(name: 'MINER_COUNT[eu-north-1]', value: miner_count['eu-north-1'] as String),
              string(name: 'POOL_ID', value: pool_id),
              string(name: 'BOOTNODES', value: bootnodes),
              string(name: 'MINER_IMAGE', value: params.MINER_IMAGE),
              string(name: 'SPACEMESH_SPACE', value: SPACEMESH_SPACE as String),
              string(name: 'SPACEMESH_VOL_SIZE', value: vol_size as String),
              string(name: 'MINER_CPU', value: params.MINER_CPU as String),
              string(name: 'MINER_MEM', value: params.MINER_MEM as String),
              string(name: 'EXTRA_PARAMS', value: extra_params.join(" ")),
              string(name: 'POET_IPS', value: poet_ips.join(" ")),
            ], propagate: true, wait: true
          }
        }
      }

      stage("Archive artifacts") {
        steps {
          script {
            def miner_params = [
              POOL_ID: pool_id,
              BOOTNODES: bootnodes,
              GATEWAYS: gateways,
              MINER_IMAGE: params.MINER_IMAGE,
              SPACEMESH_SPACE: SPACEMESH_SPACE as String,
              SPACEMESH_VOL_SIZE: vol_size as String,
              MINER_CPU: params.MINER_CPU,
              MINER_MEM: params.MINER_MEM,
              EXTRA_PARAMS: extra_params.join(" "),
              POET_IPS: poet_ips.join(" "),
            ]
            /* Save build parameters as JSON */
            writeFile file: "params.json", text: groovy.json.JsonOutput.toJson(miner_params)
          }
          archiveArtifacts "poet-deploy.yml, miner-*-bootstrap-svc.yml, miner-*-bootstrap-deploy.yml, params.json"
        }
      }
    }
  }
}

def random_port(int low=62000, int high=65535) {
  (low + (high-low)*(new Random()).nextFloat()) as int
}

/* vim: set filetype=groovy ts=2 sw=2 et : */
