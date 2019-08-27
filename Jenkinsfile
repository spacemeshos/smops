/* Seed job for spacemesh Jenkins */

repo_url = "git@bitbucket.org:automatitdevops/spacemesh-misc.git"
creds_id = "main_key"
dsl_name = "spacemesh.dsl"

/*
  PIPELINE
 */
pipeline {
  agent { label "master" }
  
  options {
    buildDiscarder(logRotator(numToKeepStr: '5')) // Keep last 5 builds only
  }

  stages {
    stage("Build DSL") {
      steps {
        writeFile file: dsl_name, text: spacemeshDSL()
      }
    }

    stage("Apply DSL") {
//      when { expression { false } } //FIXME: Enable
      steps {
        jobDsl(
               targets: dsl_name,
               failOnSeedCollision: true,
               removedConfigFilesAction: 'DELETE',
               removedJobAction: 'DELETE',
               removedViewAction: 'DELETE',
               )
      }
    }

    stage("Archive DSL") {
      steps {
        archiveArtifacts dsl_name
      }
    }
  }
}

def scmDSL(script_path="Jenkinsfile") {
  """
        cpsScm {
          lightweight()

          scm {
            git {
              remote {
                url "${repo_url}"
                credentials "${creds_id}"
              }
              branch "master"
            }
          }

          scriptPath("${script_path}")
        }
""".trim()
}

def initfactoryDSL(folder="init-factory") {
  def result = ""

  /* Define the folder for InitFactory jobs */
  result += """\
    folder("${folder}") {
      description("Jobs related to InitFactory")
    }
  """.stripIndent()
  
  /* build-image pipeline */
  result += """\
    pipelineJob("${folder}/build-image") {
      description("Bulds an image for InitFactory's initContainer")
      definition {
        ${scmDSL("initfactory/Jenkinsfile.build")}
      }
    }
  """.stripIndent()

  /* run-workers pipeline */
  result += """\
    pipelineJob("${folder}/run-workers") {
      description("Runs a specified number of InitFactory workers")
      definition {
        ${scmDSL("initfactory/Jenkinsfile")}
      }
    }
  """.stripIndent()

  /* cleanup-workers pipeline */
  result += """\
    pipelineJob("${folder}/cleanup-workers") {
      description("Cleans up completed InitFactory workers")
      triggers {
        cron "H/15 * * * *"
      }
      definition {
        ${scmDSL("initfactory/Jenkinsfile.cleanup")}
      }
    }
  """.stripIndent()

  return result
}

def minerDSL(folder="miner-us-east-1") {
  def result = ""

  /* Define the folder for InitFactory jobs */
  result += """\
    folder("${folder}") {
      description("Jobs related to Miner in us-east-1 AWS region")
    }
  """.stripIndent()

  /* build-init-image pipeline */
  result += """\
    pipelineJob("${folder}/build-init-image") {
      description("Builds container image for Miner's initContainer")
      definition {
        ${scmDSL("miner/Jenkinsfile.build")}
      }
    }
  """.stripIndent()

  /* run-miners pipeline */
  result += """\
    pipelineJob("${folder}/run-miners") {
      description("Runs a specified number of miners")
      definition {
        ${scmDSL("miner/Jenkinsfile")}
      }
    }
  """.stripIndent()

  /* stop-miners pipeline */
  result += """\
    pipelineJob("${folder}/stop-miners") {
      description("Stops running miners")
      definition {
        ${scmDSL("miner/Jenkinsfile.stop-miners")}
      }
    }
  """.stripIndent()

  /* unlock-data pipeline */
  result += """\
    pipelineJob("${folder}/unlock-data") {
      description("Removes locks on InitFactory-generated data")
      definition {
        ${scmDSL("miner/Jenkinsfile.unlock")}
      }
    }
  """.stripIndent()

  return result
}

def spacemeshDSL() {
  def result = ""

  result += initfactoryDSL("init-factory")
  result += minerDSL("miner-us-east-1")

  return result
}

/* vim: set filetype=groovy ts=2 sw=2 et : */
