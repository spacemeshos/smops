/* Seed job for spacemesh Jenkins */

repo_url = "https://github.com/spacemeshos/smops.git"
//creds_id = "main_key"
dsl_name = "spacemesh.dsl"

top_folder = "testnet"
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
  def default_columns = """\
      columns {
        status()
        weather()
        name()
        lastSuccess()
        lastFailure()
        lastDuration()
        buildButton()
      }
  """.trim()
  def region_names = aws_regions.collect({"""name "$it\""""}).join("\n")

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
                    /* credentialsId "\${creds_id}" */
                  }
                }
              }
            }
            defaultVersion("master")
          }
        }
      }
    }

    views {
      listView("Default") {
        description "TestNet-wide jobs"
        jobs {
          name "unlock-initdata"
          name "start-miners"
          name "stop-miners"
          name "start-initfactory"
          name "cleanup-initfactory-workers"
        }
        ${default_columns}
      }
      listView("Regions") {
        description "TestNet regions"
        jobs {
          ${region_names}
        }
        ${default_columns}
      }
    }

    primaryView("Default")
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

def buildJobPerRegions(job_name) {
  """\
    @Library("spacemesh") import static io.spacemesh.awsinfra.commons.*
    pipeline {
      agent any

      stages {
        stage("Run jobs") {
          steps {
            script {
              parallel aws_regions.collectEntries {region-> [(region): {->
                build job: "./\${region}/${job_name}"
              }]}
            }
          }
        }
      }
    }
  """.stripIndent()
}

def testnetCleanAllDSL(top_folder) {
  def pipeline = buildJobPerRegions("clean-initfactory-workers")

  """\
  pipelineJob("${top_folder}/cleanup-initfactory-workers") {
    description "Clean all the finished InitFactory workers in all regions"

    triggers {
      cron "H/15 * * * *"
    }

    definition {
      cps {
        sandbox()
        script '''${pipeline}'''
      }
    }
  }
  """.stripIndent()
}

def testnetUnlockAllDSL(top_folder) {
  def pipeline = buildJobPerRegions("unlock-initdata")

  """\
  pipelineJob("${top_folder}/unlock-initdata") {
    description "Unlock all the init data sets in all regions"
    definition {
      cps {
        sandbox()
        script '''${pipeline}'''
      }
    }
  }
  """.stripIndent()
}

def testnetDSL() {
  def result = ""

  result += topFolderDSL(top_folder, "Jobs related to TestNet deployment", "TestNet")

  aws_regions.each {region->
    result += folderDSL("${top_folder}/${region}", "Jobs related to ${region} region")

    /* InitFactory */
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

    /* Miner */
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

    /* Tools */
    result += simpleJobDSL(
      "${top_folder}/${region}/unlock-initdata",
      "unlockDataSet(\"${region}\")",
      "Unlock InitFactory data in the region",
    )
  }

  /* TestNet-global tasks */
  result += testnetCleanAllDSL(top_folder)
  result += testnetUnlockAllDSL(top_folder)

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
                /* credentials "\${creds_id}" */
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

  /* build-metrics-image pipeline */
  result += """\
    pipelineJob("global/build-metrics-image") {
      description("Bulds an image for metrics scraper")
      definition {
        ${scmDSL("metrics/Jenkinsfile.build")}
      }
    }
  """.stripIndent()

  /* inventory-dashboards */
  result += """\
    pipelineJob("global/inventory-dashboards") {
      description("Build a table with URLs of all the Kubernetes Dashboards")

      logRotator {
        artifactDaysToKeep(-1)
        artifactNumToKeep(5)
        daysToKeep(-1)
        numToKeep(24)
      }

      triggers {
        cron "H * * * *"
      }

      definition {
        cps {
          sandbox()
          script '''
            @Library("spacemesh") _

            pipeline {
               agent any

               stages {
                  stage("Prepare") {
                     steps {
                        writeFile file: "inventory.py",
                                  text: libraryResource("scripts/get_dashboard_urls.py")
                     }
                  }
                  
                  stage("Run") {
                      steps {
                          sh \"""python3 inventory.py > index.html\"""
                      }
                  }
                  
                  stage("Archive") {
                      steps {
                          archiveArtifacts "index.html"
                      }
                  }
               }
            }
          '''.stripIndent()
        }
      }
    }
  """.stripIndent()

  /* inventory-initdata */
  result += """\
    pipelineJob("global/inventory-initdata") {
      description("Build a table with list of init data files in all regions")

      logRotator {
        artifactDaysToKeep(-1)
        artifactNumToKeep(5)
        daysToKeep(-1)
        numToKeep(24)
      }

      triggers {
        cron "H H * * *"
      }

      definition {
        cps {
          sandbox()
          script '''
            @Library("spacemesh") _
            initfactoryInventory()
          '''.stripIndent()
        }
      }
    }
  """.stripIndent()

  /* Add TestNet folder and projects */
  result += testnetDSL()

  return result
}

/* vim: set filetype=groovy ts=2 sw=2 et : */
