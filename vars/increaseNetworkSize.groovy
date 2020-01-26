/*
  Increase TestNet size

  Example:

    @Library("spacemesh") _
    increateNetworkSize()
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
    }

    stages {
      stage("Prepare") {
        steps {
          cleanWs()

          echo "params: ${params}"

          script {
            echo "Ensure miner count is positive"
            aws_regions.each {region->
              miner_count[region] = params.getOrDefault("MINER_COUNT[${region}]" as String, "0") as int
            }
            assert miner_count.values().sum() > 0
          }


          script {
            if(!params.POOL_ID) {
              echo "Copy params.json from the latest start-network run"
              copyArtifacts filter: "params.json",
                            projectName: "./start-miners",
                            fingerprintArtifacts: true,
                            flatten: true,
                            selector: lastSuccessful()

              echo "Load params.json"
              def params_json = readFile("params.json")
              params.putAll((new groovy.json.JsonSlurper()).parseText(params_json))
            }
          }

          echo " >>> Number of miners: ${miner_count}"
          echo " >>> Miner parameters: ${params}"
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
                            string(name: 'POOL_ID', value: params.POOL_ID),
                            string(name: 'BOOTNODES', value: params.BOOTNODES),
                            string(name: 'MINER_IMAGE', value: params.MINER_IMAGE),
                            string(name: 'SPACEMESH_SPACE', value: params.SPACEMESH_SPACE),
                            string(name: 'SPACEMESH_VOL_SIZE', value: params.SPACEMESH_VOL_SIZE),
                            string(name: 'EXTRA_PARAMS', value: params.EXTRA_PARAMS),
                            string(name: 'POET_IPS', value: params.POET_IPS),
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
