/*
  Start TestNet miner nodes in the region

  Example:

    @Library("spacemesh") _
    runMiners("us-east-1")
*/

def call(String aws_region) {
  /* Defaults */
  default_miner_image = "spacemeshos/go-spacemesh:develop"

  /* Pipeline global vars */
  miner_count = 0
  worker_ports = []
  bootnodes = ""
  extra_params = []

  /* Library function: generate random hex string */
  random_id = {->
    def rnd = new Random()
    return {-> String.format("%06x",(rnd.nextFloat() * 2**31) as Integer)[0..5]}
  }()

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

      string name: 'GENESIS_TIME', defaultValue: '', trim: true, \
             description: 'Genesis time'

      string name: 'GENESIS_DELAY', defaultValue: '15', trim: true, \
             description: 'Genesis delay from now, minutes'

      string name: 'SPACEMESH_SPACE',defaultValue: '256G', trim: true, \
             description: 'Init file space size. Appeng G for GiB, M for MiB'

      string name: 'SPACEMESH_VOL_SIZE', defaultValue: '300', trim: true, \
             description: 'Miner job volume space, in GB'

      string name: 'EXTRA_PARAMS', defaultValue: '', trim: true, \
             description: 'Extra parameters to miner'
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

            assert vol_size > 0
            assert miner_count > 0

            pool_id = params.POOL_ID ?: random_id()

            if(params.EXTRA_PARAMS.trim()) {
              extra_params = params.EXTRA_PARAMS.trim().tokenize()
            }

            if(params.BOOTNODES) {
              extra_params += ["--bootstrap", "--bootnodes", params.BOOTNODES]
            }

            def genesis_time = ""

            if(params.GENESIS_TIME) {
              genesis_time = params.GENESIS_TIME
            } else if(params.GENESIS_DELAY) {
              genesis_time = (new Date(currentBuild.startTimeInMillis + (params.GENESIS_DELAY as int)*60*1000)).format("yyyy-MM-dd'T'HH:mm:ss'+00:00'")
            }

            if(genesis_time) {
              extra_params += ["--genesis-time", genesis_time]
            }

            worker_ports = random_ports(miner_count)
            worker_ports.sort()
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
            worker_ports.eachWithIndex({port, i ->
              i++
              def i_str = String.format("%04d", i)
              startMinerNode aws_region: aws_region, pool_id: pool_id, node_id: "node-${i_str}", \
                             miner_image: params.MINER_IMAGE, port: port, \
                             spacemesh_space: SPACEMESH_SPACE, vol_size: vol_size, \
                             params: extra_params
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

def random_ports(int ctr, int low=61000, int high=65535) {
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
