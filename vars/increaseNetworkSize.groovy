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

      string name: 'MINER_IMAGE', defaultValue: '', trim: true, \
             description: 'To use the image the other miners used, leave empty'

      string name: 'LABELS', defaultValue: '', trim: true, \
             description: 'List of key=value miner labels (separated by whitespaces)'
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
            if(params.POOL_ID) {
              miner_params = params;
            } else {
              echo "Copy params.json from the latest start-network run"
              copyArtifacts filter: "params.json",
                            projectName: "./start-miners",
                            fingerprintArtifacts: true,
                            flatten: true,
                            selector: lastSuccessful()

              echo "Load params.json"
              def params_json = readFile("params.json")
              miner_params.putAll((new groovy.json.JsonSlurper()).parseText(params_json))

              miner_params.LABELS = params.LABELS
              if(params.MINER_IMAGE) {
                miner_params.MINER_IMAGE = params.MINER_IMAGE
              }
            }
          }

          echo " >>> Number of miners: ${miner_count}"
          echo " >>> Miner parameters: ${miner_params}"
        }
      }

      stage("Create workers") {
        steps {
          script {
            def stages = [:]
            aws_regions.each {region->
              if(miner_count[region]) {
                stages[region] = {->
                  echo "Starting miners at region ${region}"
                  runMinersJob = build job: "./${region}/run-miners", parameters: [
                            string(name: 'MINER_COUNT', value: miner_count[region] as String),
                            string(name: 'POOL_ID', value: miner_params.POOL_ID),
                            string(name: 'MINER_IMAGE', value: miner_params.MINER_IMAGE),
                            string(name: 'SPACEMESH_SPACE', value: miner_params.SPACEMESH_SPACE),
                            string(name: 'SPACEMESH_VOL_SIZE', value: miner_params.SPACEMESH_VOL_SIZE),
                            string(name: 'MINER_CPU', value: miner_params.MINER_CPU),
                            string(name: 'MINER_MEM', value: miner_params.MINER_MEM),
                            string(name: 'LABELS', value: miner_params.LABELS),
                            string(name: 'POET_IPS', value: miner_params.POET_IPS),
                          ], propagate: true, wait: true
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
