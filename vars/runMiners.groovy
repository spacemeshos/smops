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

      string name: 'POET_IPS', defaultValue: '', trim: true, \
             description: 'List of PoETs (separated by whitespaces)'

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
            poet_ips = params.POET_IPS.tokenize()

            assert miner_count > 0
            assert vol_size > 0
            assert poet_ips.size() > 0

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

            worker_ports = random_ports(miner_count)
            worker_ports.sort()
          }
          echo "Number of miners: ${miner_count}"
          echo "Miner pool ID: ${pool_id}"
          echo "Miner ports: ${worker_ports}"
        }
      }

      stage("Create workers") {
        steps {
          script {
            p = poet_ips.size()
            def builders = [:]
            worker_ports.each {port->
              builders[port] = {->
                echo "[${aws_region}]: Creating miner with port ${port}"
                startMinerNode([aws_region: aws_region, pool_id: pool_id, node_id: "${run_id}-node-${port}", \
                               miner_image: params.MINER_IMAGE, port: port, \
                               spacemesh_space: SPACEMESH_SPACE, vol_size: vol_size, \
                               cpu: params.MINER_CPU, mem: params.MINER_MEM, \
                               poet_ip: poet_ips[port%p], \
                               labels: params.LABELS])
              }
            }
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

/* vim: set filetype=groovy ts=2 sw=2 et : */
