/*
  Remove the specified number of TestNet miner nodes in the region

  Example:

    @Library("spacemesh") _
    removeMiners("us-east-1")
*/

import static io.spacemesh.awsinfra.commons.*

def call(String aws_region) {
  /* Pipeline global vars */
  miner_count = 0
  stop_list = []
  kubectl = "kubectl --context=miner-${aws_region}"

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
    }

    stages {
      stage("Prepare") {
        steps {
          cleanWs()

          script {
            miner_count = params.MINER_COUNT as int
            assert miner_count > 0

	    pool_id = params.POOL_ID ?: ""
          }
          echo "Number of miners to remove: ${miner_count}"
          echo "Miner pool ID: '${pool_id}'"
        }
      }

      stage("Get miners to stop") {
      	steps {
          script {
            def selector = "app=miner" + (pool_id ? ",miner-pool=${pool_id}" : "")
            def out_tpl = "{{range .items}}{{.metadata.name | printf \"%s\\n\"}}{{end}}"
            stop_list = shell("""${kubectl} get deploy -l ${selector} --template '${out_tpl}' | shuf | head -n ${miner_count}""").split()
            assert stop_list : "No running miners found"
          }
          echo "Worker(s) to stop: ${stop_list}"
        }
      }

      stage("Stop workers") {
        steps {
          sh """${kubectl} delete pvc,deploy ${stop_list.join(" ")}"""
        }
      }
    }
  }
}

/* vim: set filetype=groovy ts=2 sw=2 et : */
