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
  poet_rest_lb = "af1cbcd27574011eaad71167fe06fe2e-425091448.us-east-1.elb.amazonaws.com"

  /* Pipeline global vars */
  poet_params = ''
  gateway_count = 0
  miner_count = [:]
  config_toml = [:]

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

      string name: 'SPACEMESH_VOL_SIZE', defaultValue: '10', trim: true, \
             description: 'Miner job volume space, in GB'

      string name: 'SPACEMESH_SPACE',defaultValue: '256G', trim: true, \
             description: 'Init file space size. Appeng G for GiB, M for MiB'

      string name: 'LAYER_DURATION_SEC', defaultValue: '300', trim: true, description: ''
      string name: 'LAYER_AVERAGE_SIZE', defaultValue: '30', trim: true, description: ''
      string name: 'LAYERS_PER_EPOCH', defaultValue: '6', trim: true, description: ''
      string name: 'GENESIS_ACTIVE_SIZE', defaultValue: '50', trim: true, description: ''
      string name: 'SYNC_REQUEST_TIMEOUT', defaultValue: '20000', trim: true, description: ''
      string name: 'HDIST', defaultValue: '7', trim: true, description: ''
      string name: 'ATXS_PER_BLOCK', defaultValue: '100', trim: true, description: ''
      string name: 'POST_LABELS', defaultValue: '100', trim: true, description: ''
      string name: 'NETWORK_ID', defaultValue: '1', trim: true, description: ''
      string name: 'RANDCON', defaultValue: '8', trim: true, description: ''
      string name: 'MAX_INBOUND', defaultValue: '100', trim: true, description: ''
      string name: 'BASE_REWARD', defaultValue: '50000000000000', trim: true, description: ''
      string name: 'HARE_COMMITTEE_SIZE', defaultValue: '30', trim: true, description: ''
      string name: 'HARE_MAX_ADVERSARIES', defaultValue: '14', trim: true, description: ''
      string name: 'HARE_ROUND_DURATION_SEC', defaultValue: '30', trim: true, description: ''
      string name: 'HARE_LIMIT_ITERATIONS', defaultValue: '10', trim: true, description: ''
      string name: 'HARE_EXP_LEADERS', defaultValue: '5', trim: true, description: ''
      string name: 'HARE_WAKEUP_DELTA', defaultValue: '30', trim: true, description: ''
      string name: 'ELIGIBILITY_CONFIDENCE_PARAM', defaultValue: '25', trim: true, description: ''
      string name: 'ELIGIBILITY_EPOCH_OFFSET', defaultValue: '0', trim: true, description: ''
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

            pool_id = params.POOL_ID ?: random_id()

            assert (params.POET_N as Integer) > 0
            poet_params = "--n ${params.POET_N}"

            if(params.POET_DURATION) {
              poet_params += " --duration ${params.POET_DURATION}"
            }

            assert (params.POET_COUNT as Integer) > 0
            assert params.POET_INITIALDURATION.tokenize().size() == (params.POET_COUNT as Integer)

            gateway_count = (params.GATEWAY_MINER_COUNT as Integer) - 1
            assert gateway_count >= 0

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

            config_toml = [
              LAYER_DURATION_SEC: params.LAYER_DURATION_SEC,
              LAYER_AVERAGE_SIZE: params.LAYER_AVERAGE_SIZE,
              LAYERS_PER_EPOCH: params.LAYERS_PER_EPOCH,
              POET_SERVER: poet_rest_lb,
              GENESIS_ACTIVE_SIZE: params.GENESIS_ACTIVE_SIZE,
              SYNC_REQUEST_TIMEOUT: params.SYNC_REQUEST_TIMEOUT,
              HDIST: params.HDIST,
              ATXS_PER_BLOCK: params.ATXS_PER_BLOCK,
              NETWORK_ID: params.NETWORK_ID,
              MAX_INBOUND: params.MAX_INBOUND,
              BOOTSTRAP: 'false',
              RANDCON: params.RANDCON,
              P2P: [],
              POST_SPACE: SPACEMESH_SPACE as String,
              POST_LABELS: params.POST_LABELS,
              BASE_REWARD: params.BASE_REWARD,
              HARE_COMMITTEE_SIZE: params.HARE_COMMITTEE_SIZE,
              HARE_MAX_ADVERSARIES: params.HARE_MAX_ADVERSARIES,
              HARE_ROUND_DURATION_SEC: params.HARE_ROUND_DURATION_SEC,
              HARE_LIMIT_ITERATIONS: params.HARE_LIMIT_ITERATIONS,
              HARE_EXP_LEADERS: params.HARE_EXP_LEADERS,
              HARE_WAKEUP_DELTA: params.HARE_WAKEUP_DELTA,
              ELIGIBILITY_CONFIDENCE_PARAM: params.ELIGIBILITY_CONFIDENCE_PARAM,
              ELIGIBILITY_EPOCH_OFFSET: params.ELIGIBILITY_EPOCH_OFFSET,
            ]

            kubectl_boot = "kubectl --context=miner-${params.BOOT_REGION}"
          }

          echo " >>> Number of gateways/bootstraps: ${gateway_count + 1}"
          echo " >>> Total number of miners: ${miner_count}"
          echo " >>> Miner pool ID: ${pool_id}"
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

            config_toml.GENESIS_TIME = (new Date(currentBuild.startTimeInMillis + (params.GENESIS_DELAY as int)*60*1000)).format("yyyy-MM-dd'T'HH:mm:ss'+00:00'")
            echo " >>> Genesis time: ${config_toml.GENESIS_TIME}"

            createToml(config_toml, kubectl_boot)

            runMinersJob = build job: "./${params.BOOT_REGION}/run-miners", parameters: [
              string(name: 'MINER_COUNT', value: '1'),
              string(name: 'POOL_ID', value: pool_id),
              string(name: 'MINER_IMAGE', value: params.MINER_IMAGE),
              string(name: 'SPACEMESH_SPACE', value: SPACEMESH_SPACE as String),
              string(name: 'SPACEMESH_VOL_SIZE', value: vol_size as String),
              string(name: 'MINER_CPU', value: params.MINER_CPU as String),
              string(name: 'MINER_MEM', value: params.MINER_MEM as String),
              string(name: 'POET_IPS', value: poet_ips.join(' ')),
              string(name: 'LABELS', value: 'miner-role=gateway'),
            ], propagate: true, wait: true

            spacemesh_url = 'spacemesh://{.metadata.labels.miner-id}@{.metadata.labels.miner-ext-ip}:{.metadata.labels.miner-ext-port}'
            boot_miner = shell("""\
              ${kubectl_boot} wait pod -l miner-role=gateway --for=condition=ready --timeout=360s \
              -o 'jsonpath=${spacemesh_url}'""")
            
            echo "boot_miner: $boot_miner"
            
            config_toml.BOOTSTRAP = 'true'
            config_toml.P2P = [boot_miner]
            createToml(config_toml, kubectl_boot)
            
            if(gateway_count) {
              echo "Extra gateways/bootstraps"
              runMinersJob = build job: "./${params.BOOT_REGION}/run-miners", parameters: [
                string(name: 'MINER_COUNT', value: gateway_count as String),
                string(name: 'POOL_ID', value: pool_id),
                string(name: 'MINER_IMAGE', value: params.MINER_IMAGE),
                string(name: 'SPACEMESH_SPACE', value: SPACEMESH_SPACE as String),
                string(name: 'SPACEMESH_VOL_SIZE', value: vol_size as String),
                string(name: 'MINER_CPU', value: params.MINER_CPU as String),
                string(name: 'MINER_MEM', value: params.MINER_MEM as String),
                string(name: 'POET_IPS', value: poet_ips.join(' ')),
                string(name: 'LABELS', value: 'miner-role=gateway'),
              ], propagate: true, wait: true
            }

            bootnodes = shell("""\
              ${kubectl_boot} wait pod -l miner-role=gateway --for=condition=ready --timeout=360s \
              -o 'jsonpath=${spacemesh_url} '""").tokenize()

            config_toml.P2P += bootnodes
            createToml(config_toml, kubectl_boot)
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
              string(name: 'MINER_IMAGE', value: params.MINER_IMAGE),
              string(name: 'SPACEMESH_SPACE', value: SPACEMESH_SPACE as String),
              string(name: 'SPACEMESH_VOL_SIZE', value: vol_size as String),
              string(name: 'MINER_CPU', value: params.MINER_CPU as String),
              string(name: 'MINER_MEM', value: params.MINER_MEM as String),
              string(name: 'POET_IPS', value: poet_ips.join(' ')),
            ], propagate: true, wait: true
          }
        }
      }

      stage("Archive artifacts") {
        steps {
          script {
            def miner_params = [
              BOOT_REGION: params.BOOT_REGION,
              POOL_ID: pool_id,
              GATEWAYS: gateways,
              MINER_IMAGE: params.MINER_IMAGE,
              SPACEMESH_SPACE: SPACEMESH_SPACE as String,
              SPACEMESH_VOL_SIZE: vol_size as String,
              MINER_CPU: params.MINER_CPU,
              MINER_MEM: params.MINER_MEM,
              POET_IPS: poet_ips.join(' '),
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

def createToml(Map cfg, String kubectl_boot) {
  echo "Writing config.toml"
  writeFile file: "config.toml", \
    text: ("""\
      [main]
      genesis-time = "${cfg.GENESIS_TIME}"
      layer-duration-sec = "${cfg.LAYER_DURATION_SEC}"
      layer-average-size = "${cfg.LAYER_AVERAGE_SIZE}"
      layers-per-epoch = "${cfg.LAYERS_PER_EPOCH}"
      poet-server = "${cfg.POET_SERVER}"
      genesis-active-size = "${cfg.GENESIS_ACTIVE_SIZE}"
      sync-request-timeout = "${cfg.SYNC_REQUEST_TIMEOUT}"
      hdist = "${cfg.HDIST}"
      atxs-per-block = "${cfg.ATXS_PER_BLOCK}"

      [p2p]
      network-id = "${cfg.NETWORK_ID}"
      max-inbound = "${cfg.MAX_INBOUND}"

      [p2p.swarm]
      bootstrap = ${cfg.BOOTSTRAP}
      randcon = "${cfg.RANDCON}"
      bootnodes = ${groovy.json.JsonOutput.toJson(cfg.P2P)}

      [api]

      [time]

      [post]
      post-space = "${cfg.POST_SPACE}"
      post-labels = "${cfg.POST_LABELS}"

      [reward]
      base-reward = {abs = "${cfg.BASE_REWARD}"}

      [hare]
      hare-committee-size = "${cfg.HARE_COMMITTEE_SIZE}"
      hare-max-adversaries = "${cfg.HARE_MAX_ADVERSARIES}"
      hare-round-duration-sec = "${cfg.HARE_ROUND_DURATION_SEC}"
      hare-limit-iterations = "${cfg.HARE_LIMIT_ITERATIONS}"
      hare-exp-leaders = "${cfg.HARE_EXP_LEADERS}"
      hare-wakeup-delta = "${cfg.HARE_WAKEUP_DELTA}"

      [hare-eligibility]
      eligibility-confidence-param = "${cfg.ELIGIBILITY_CONFIDENCE_PARAM}"
      eligibility-epoch-offset = "${cfg.ELIGIBILITY_EPOCH_OFFSET}"
      """).stripIndent()

  def builders = [:]
  aws_regions.each {region->
    builders[region] = {->
      def kubectl = "kubectl --context=miner-${region}"
      sh """$kubectl create configmap miner-files --from-file=config.toml --dry-run -o yaml | $kubectl apply -f -"""
    }
  }
  parallel builders

  sh """$kubectl_boot rollout restart deployment/config-toml"""
}

/* vim: set filetype=groovy ts=2 sw=2 et : */
