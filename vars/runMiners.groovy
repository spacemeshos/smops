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
             description: 'Miner pool id'

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
            worker_ports.eachWithIndex({port, i ->
              i_str = String.format("%04d", i)
              startMinerNode aws_region: aws_region, pool_id: pool_id, node_id: "${run_id}-node-${i_str}", \
                             miner_image: params.MINER_IMAGE, port: port, \
                             spacemesh_space: SPACEMESH_SPACE, vol_size: vol_size, \
                             cpu: params.MINER_CPU, mem: params.MINER_MEM, \
                             params: extra_params, \
                             poet_ip: poet_ips[i%p], \
                             labels: params.LABELS
            })
          }
        }
      }

      stage("Archive artifacts") {
        steps {
          archiveArtifacts "miner-*-node-0001-deploy.yml"
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
