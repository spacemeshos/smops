/* Seed job for spacemesh Jenkins */

repo_url = "git@bitbucket.org:automatitdevops/spacemesh-misc.git"
creds_id = "main_key"
dsl_name = "spacemesh.dsl"

top_folder = "testnet"
aws_regions = [
  "ap-northeast-2",
  "eu-north-1",
//  "us-east-1",
  "us-east-2",
  "us-west-2",
  ]

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

def topFolderDSL(name, desc="", display_name="") {
  """\
  folder("${name}") {
    description "${desc}"
    displayName "${display_name}"
    properties {
      folderLibraries {
        libraries {
          libraryConfiguration {
            name("spacemesh")
            retriever {
              modernSCM {
                scm {
                  git {
                    remote "${repo_url}"
                    credentialsId "${creds_id}"
                  }
                }
              }
            }
            defaultVersion("master")
          }
        }
      }
    }
  }
  """.stripIndent()
}

def folderDSL(name, desc="") {
  """\
  folder("${name}") {
    description "${desc}"
  }
  """.stripIndent()
}

def simpleJobDSL(name, func, desc="") {
  """\
  pipelineJob("${name}") {
    description "${desc}"
    definition {
      cps {
        sandbox()
        script '''\\
          @Library("spacemesh") _
          ${func}
        '''.stripIndent()
      }
    }
  }
  """.stripIndent()
}

def testnetDSL() {
  def result = ""

  result += topFolderDSL(top_folder, "Jobs related to TestNet deployment", "TestNet")

  aws_regions.each {region->
    result += folderDSL("${top_folder}/${region}")
    result += simpleJobDSL(
      "${top_folder}/${region}/run-initfactory-workers",
      "runInitFactoryWorkers(\"${region}\")",
      "Run InitFactory workers in the region",
    )
    result += simpleJobDSL(
      "${top_folder}/${region}/clean-initfactory-workers",
      "cleanInitFactoryWorkers(\"${region}\")",
      "Clean completed InitFactory jobs in the region",
    )
    result += simpleJobDSL(
      "${top_folder}/${region}/run-miners",
      "runMiners(\"${region}\")",
      "Run Miners in the region",
    )
    result += simpleJobDSL(
      "${top_folder}/${region}/stop-miners",
      "stopMiners(\"${region}\")",
      "Stop Miners in the region",
    )
  }

  return result
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

def spacemeshDSL() {
  def result = ""

  /* Add Global folder */
  result += """\
  folder("global") {
    displayName "Global"
    description "Jobs for all the regions"
  }
  """.stripIndent()

  /* build-miner-init-image pipeline */
  result += """\
    pipelineJob("global/build-miner-init-image") {
      description("Builds container image for Miner's initContainer")
      definition {
        ${scmDSL("miner/Jenkinsfile.build")}
      }
    }
  """.stripIndent()

  /* build-initfactory-image pipeline */
  result += """\
    pipelineJob("global/build-initfactory-image") {
      description("Bulds an image for InitFactory")
      definition {
        ${scmDSL("initfactory/Jenkinsfile.build")}
      }
    }
  """.stripIndent()

  /* Add TestNet folder and projects */
  result += testnetDSL()

  return result
}

/* vim: set filetype=groovy ts=2 sw=2 et : */
