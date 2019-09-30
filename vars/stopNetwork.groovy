/*
  Stop TestNet

  Example:

    @Library("spacemesh") _
    stopNetwork()
*/

def call(String aws_region) {
  /* Defaults */
  default_miner_image = "spacemeshos/go-spacemesh:develop"
  aws_regions = [
    "ap-northeast-2",
    "eu-north-1",
    "us-east-1",
    "us-east-2",
    "us-west-2",
  ]

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
    }
  }
}

/* vim: set filetype=groovy ts=2 sw=2 et : */
