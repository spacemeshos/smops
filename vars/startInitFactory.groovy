/*
  Start InitFactory

  Example:

    @Library("spacemesh") _
    startInitFactory()
*/

import static io.spacemesh.awsinfra.commons.*

def call() {
  /* Pipeline global vars */
  worker_count = [:]

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
      string name: 'WORKER_COUNT[us-east-1]', defaultValue: '0', trim: true, \
             description: 'Number of the workers to start in us-east-1'
      string name: 'WORKER_COUNT[us-east-2]', defaultValue: '0', trim: true, \
             description: 'Number of the workers to start in us-east-2'
      string name: 'WORKER_COUNT[us-west-2]', defaultValue: '0', trim: true, \
             description: 'Number of the workers to start in us-west-2'
      string name: 'WORKER_COUNT[ap-northeast-2]', defaultValue: '0', trim: true, \
             description: 'Number of the workers to start in ap-northeast-2'
      string name: 'WORKER_COUNT[eu-north-1]', defaultValue: '0', trim: true, \
             description: 'Number of the workers to start in eu-north-1'

      string name: 'SPACEMESH_SPACE',defaultValue: '256G', trim: true, \
             description: 'Init file space size. Appeng G for GiB, M for MiB'

      string name: 'SPACEMESH_VOL_SIZE', defaultValue: '300', trim: true, \
             description: 'Worker job volume space, in GB'
    }

    stages {
      stage("Prepare") {
        steps {
          cleanWs()

          script {
            vol_size = params.SPACEMESH_VOL_SIZE as int
            assert vol_size > 0

            aws_regions.each {region->
              worker_count[region] = params.getOrDefault("WORKER_COUNT[${region}]" as String, "0") as int
            }
            assert worker_count.values().sum() > 0

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
          }

          echo " >>> Number of workers:  ${worker_count}"
          echo " >>> Init file size:     ${SPACEMESH_SPACE}"
          echo " >>> Worker volume size: ${vol_size}GiB"
        }
      }

      stage("Create workers") {
        steps {
          script {
            stages = [:]
            aws_regions.each {region->
              if(worker_count[region]) {
                stages[region] = {->
                  build job: "./${region}/run-initfactory-workers", parameters: [
                            string(name: 'INIT_COUNT', value: worker_count[region] as String),
                            string(name: 'SPACEMESH_SPACE', value: SPACEMESH_SPACE as String),
                            string(name: 'SPACEMESH_VOL_SIZE', value: vol_size as String),
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
