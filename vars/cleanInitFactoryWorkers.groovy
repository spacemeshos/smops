def call(aws_region="us-east-2") {
  /* kubectl command */
  def kubectl = "kubectl --context=initfactory-${aws_region}"

  /* Pipeline global vars */
  def job_list = []

  /*
    PIPELINE
   */
  pipeline {
    options {
      buildDiscarder(logRotator(numToKeepStr: '10')) // Keep last 10 builds only
    }

    /* Job triggers - run every 15 minutes */
    triggers{ cron('H/15 * * * *') }

    agent any

    stages {
      stage("List completed jobs") {
        steps {
          script {
            def tpl = '{{range .items}}{{.metadata.name}} {{end}}'
            job_list = shell("""\
              ${kubectl} get job -l app=initfactory --field-selector status.successful==1 --template '${tpl}'""").split()
          }
        }
      }

      stage("Clean up completed jobs") {
        steps {
          script {
            job_list.each({job ->
              sh """${kubectl} delete pvc,job -l app=initfactory,worker-id=${job}"""
            })
          }
        }
      }
    }
  }
}

/* vim:set filetype=groovy ts=2 sw=2 et: */
