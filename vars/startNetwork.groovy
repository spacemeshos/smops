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
  poet_initialduration = []
  miner_count = [:]
  bootnode = [:]
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
      string name: 'POET_PARAMS', defaultValue: "--n 23", trim: true, \
             description: 'PoET parameters'
      string name: 'POET_COUNT', defaultValue: '1', trim: true, \
             description: 'Number of PoETs to start'
      string name: 'POET_INITIAL_DURATION', defaultValue: '0', trim: true, \
             description: '--initialduration per PoET'

      string name: 'GATEWAY_MINER_COUNT', defaultValue: '0', trim: true, \
             description: 'Number of the gateway miners to start in bootstrap region'

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

      string name: 'GENESIS_DELAY', defaultValue: '10', trim: true, \
             description: 'Genesis delay from now, minutes'

      string name: 'SPACEMESH_SPACE',defaultValue: '256G', trim: true, \
             description: 'Init file space size. Appeng G for GiB, M for MiB'

      string name: 'SPACEMESH_VOL_SIZE', defaultValue: '300', trim: true, \
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

            if(params.POET_PARAMS) {
              poet_params = params.POET_PARAMS.tokenize()
            }

            poet_initialduration = params.POET_INITIAL_DURATION.tokenize()
            assert poet_initialduration.size() == (params.POET_COUNT as Integer)

            genesis_time = (new Date(currentBuild.startTimeInMillis + (params.GENESIS_DELAY as int)*60*1000)).format("yyyy-MM-dd'T'HH:mm:ss'+00:00'")
            extra_params += ["--genesis-time", genesis_time]

            bootstrap_port = random_port()
          }

          echo " >>> Number of miners: ${miner_count}"
          echo " >>> Miner pool ID: ${pool_id}"
          echo " >>> Extra miner params: ${extra_params}"
          echo " >>> Bootstrap node port: ${bootstrap_port}"
        }
      }

      stage("Create PoETs") {
        steps {
          startPoET image: params.POET_IMAGE, count: params.POET_COUNT, params: poet_params.join(' '), initialduration: poet_initialduration.join(' ')
          script {
            poet_ips = shell("""${kubectl_poet} get pod -l app=poet -o 'jsonpath={.items[*].status.podIP}'""")
            poet_ips = poet_ips.tokenize()
            echo "poet_ips: ${poet_ips}"
          }
        }
      }

      stage("Start bootstrap node") {
        steps {
          script {
            bootnode = startBootstrapNode(aws_region: params.BOOT_REGION, pool_id: pool_id, \
                                          miner_image: params.MINER_IMAGE, port: bootstrap_port, \
                                          vol_size: vol_size, spacemesh_space: SPACEMESH_SPACE, \
                                          params: extra_params, \
                                          poet_ip: poet_ips[0] \
                                          )
          }
        }
      }

      stage("Create gateway workers") {
        steps {
          script {
            if(params.GATEWAY_MINER_COUNT as Integer) {
              runMinersJob = build job: "./${params.BOOT_REGION}/run-miners", parameters: [
                        string(name: 'MINER_COUNT', value: params.GATEWAY_MINER_COUNT as String),
                        string(name: 'POOL_ID', value: pool_id),
                        string(name: 'BOOTNODES', value: bootnode.netaddr as String),
                        string(name: 'MINER_IMAGE', value: params.MINER_IMAGE),
                        string(name: 'SPACEMESH_SPACE', value: SPACEMESH_SPACE as String),
                        string(name: 'SPACEMESH_VOL_SIZE', value: vol_size as String),
                        string(name: 'EXTRA_PARAMS', value: extra_params.join(" ")),
                        string(name: 'POET_IPS', value: poet_ips.join(" ")),
                      ]

              echo "Waiting for gateway miners to be ready"
              timeout(360) {
                waitUntil {
                  script {
                    r = shell("""kubectl --context=miner-${params.BOOT_REGION} wait pod -l app=miner,miner-node!=bootstrap --for=condition=ready --timeout=360s 2>/dev/null""")
                    return (r.count("condition met") == params.GATEWAY_MINER_COUNT as Integer)
                  }
                }
              }
            }
          }
        }
      }

      stage("Getting gateway miners") {
        steps {
          script {
            gosipAddrs = [bootnode.netaddr]
            grpcAddrs = [bootnode.nodeaddr]
            vals = shell("""kubectl --context=miner-${params.BOOT_REGION} get pod -l app=miner,miner-node!=bootstrap -o 'jsonpath={range .items[*]}{.metadata.name},{.spec.nodeName},{.status.podIP},{.spec.containers[0].env[0].value} {end}'""")
            vals = vals.tokenize()
            vals.each {pod_miner_ip_port->
              (podName, minerName, podIP, minerPort) = pod_miner_ip_port.tokenize(',')
              minerIP = shell("""kubectl --context=miner-${params.BOOT_REGION} get node ${minerName} -o 'jsonpath={.status.addresses[1].address}'""")
              retry(10) {
                minerID = shell("""kubectl --context=miner-${params.BOOT_REGION} logs ${podName} |\\
                    sed -ne '/Local node identity / { s/.\\+Local node identity >> \\([a-zA-Z0-9]\\+\\).*/\\1/ ; p; q; }'
                """.stripIndent().trim())

                gosipAddr = "spacemesh://${minerID}@${minerIP}:${minerPort}"
                grpcAddr = "${podIP}:9091"
              }
              gosipAddrs.add(gosipAddr)
              grpcAddrs.add(grpcAddr)
            }
            multi_netaddr = gosipAddrs.join(",")
            multi_nodeaddr = groovy.json.JsonOutput.toJson(grpcAddrs)
            echo """\
              >>> Bootstrap nodes: ${multi_netaddr}
              >>> Gateway nodes: ${multi_nodeaddr}
              """.stripIndent()
          }
        }
      }
      
      stage("Start PoETs") {
        steps {
          script {
            poet_ips.each {poet_ip->
              sh """curl -is --data '{"gatewayAddresses": ${multi_nodeaddr}}' ${poet_ip}:8080/v1/start >/dev/null"""
            }
          }
        }
      }

      stage("Create genesis miners") {
        steps {
          script {
            build job: "./increase-network", parameters: [
              string(name: 'MINER_COUNT[ap-northeast-2]', value: miner_count['ap-northeast-2'] as String),
              string(name: 'MINER_COUNT[eu-north-1]', value: miner_count['eu-north-1'] as String),
              string(name: 'MINER_COUNT[us-east-1]', value: miner_count['us-east-1'] as String),
              string(name: 'MINER_COUNT[us-east-2]', value: miner_count['us-east-2'] as String),
              string(name: 'MINER_COUNT[us-west-2]', value: miner_count['us-west-2'] as String),
              string(name: 'POOL_ID', value: pool_id),
              string(name: 'BOOTNODES', value: multi_netaddr),
              string(name: 'MINER_IMAGE', value: params.MINER_IMAGE),
              string(name: 'SPACEMESH_SPACE', value: SPACEMESH_SPACE as String),
              string(name: 'SPACEMESH_VOL_SIZE', value: vol_size as String),
              string(name: 'EXTRA_PARAMS', value: extra_params.join(" ")),
              string(name: 'POET_IPS', value: poet_ips.join(" ")),
            ]
          }
        }
      }

      stage("Archive artifacts") {
        steps {
          script {
            def miner_params = [
              POOL_ID: pool_id,
              BOOTNODES: multi_netaddr,
              MINER_IMAGE: params.MINER_IMAGE,
              SPACEMESH_SPACE: SPACEMESH_SPACE as String,
              SPACEMESH_VOL_SIZE: vol_size as String,
              EXTRA_PARAMS: extra_params.join(" "),
              POET_IPS: poet_ips.join(" "),
              GATEWAY_MINERS: multi_nodeaddr,
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
