def call(aws_region="us-east-2") {
  kubectl = "kubectl --context=miner-${aws_region}"

  /* Pipeline-global variables */
  label_selector = 'app=miner'

  /*
    PIPELINE
   */
  pipeline {
    agent any

    options {
      buildDiscarder(logRotator(numToKeepStr: '5')) // Keep last 5 builds only
    }

    parameters {
      string name: 'POOL_ID', defaultValue: '', description: 'Miner pool id (optional)', trim: true
    }

    stages {
      stage("Stopping miners") {
        /* Skip this stage for first-time build */
        when {
          not {
            equals expected: 1, actual: currentBuild.number
          }
        }
        steps {
          script {
            if(params.POOL_ID) {
              echo "Stopping pool ${params.POOL_ID} only"
              label_selector = "miner-pool=${params.POOL_ID}"
            }
          }
          sh """${kubectl} delete svc,deploy,pvc -l ${label_selector}"""
        }
      }
    }
  }
}

/* vim: set filetype=groovy ts=2 sw=2 et : */

