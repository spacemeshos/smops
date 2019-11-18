/*
  Stop TestNet

  Example:

    @Library("spacemesh") _
    stopNetwork()
*/

import static io.spacemesh.awsinfra.commons.*

def call(String aws_region) {
  /*
    PIPELINE
   */
  pipeline {
    agent any

    options {
      buildDiscarder(logRotator(numToKeepStr: '10')) // Keep last 10 builds only
    }

    stages {
      stage("Stop workers") {
        steps {
          script {
            stages = [:]
            aws_regions.each {region->
              stages[region] = {->
                build job: "./${region}/stop-miners", propagate: false
              }
            }
            parallel stages
          }
        }
      }

      stage("Stop PoET") {
        steps {
          stopPoET()
        }
      }
    }
  }
}

/* vim: set filetype=groovy ts=2 sw=2 et : */
