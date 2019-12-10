/*
  Decrease TestNet size

  Example:

    @Library("spacemesh") _
    decreateNetworkSize()
*/

import static io.spacemesh.awsinfra.commons.*

def call(String aws_region) {
  /* Pipeline global vars */
  miner_count = [:]
  miner_params = [:]

  /*
    PIPELINE
   */
  pipeline {
    agent any

    options {
      buildDiscarder(logRotator(numToKeepStr: '10')) // Keep last 10 builds only
    }

    parameters {
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

      string name: 'POOL_ID', defaultValue: '', trim: true, \
             description: 'Miner pool id'
    }

    stages {
      stage("Prepare") {
        steps {
          script {
            echo "Ensure miner count is positive"
            aws_regions.each {region->
              miner_count[region] = params.getOrDefault("MINER_COUNT[${region}]" as String, "0") as int
            }
            assert miner_count.values().sum() > 0
          }

          cleanWs()

          echo " >>> Number of miners to stop: ${miner_count}"
        }
      }

      stage("Create workers") {
        steps {
          script {
            stages = [:]
            aws_regions.each {region->
              if(miner_count[region]) {
                stages[region] = {->
                  build job: "./${region}/remove-miners", parameters: [
                            string(name: 'MINER_COUNT', value: miner_count[region] as String),
                            string(name: 'POOL_ID', value: params.POOL_ID),
                          ], propagate: false
                }
              }
            }
            parallel stages
          }
        }
      }
    }
  }
}

/* vim: set filetype=groovy ts=2 sw=2 et : */
