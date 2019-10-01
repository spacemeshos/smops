def call(aws_region="us-east-2") {
  /*
    PIPELINE
   */
  pipeline {
    options {
      buildDiscarder(logRotator(numToKeepStr: '10')) // Keep last 10 builds only
    }

    agent any
    stages {
      stage("Get script") {
        steps {
          writeFile file: "unlock_initdata.py", text: libraryResource("scripts/unlock_initdata.py")
        }
      }

      stage("Unlock data") {
        steps {
          sh """python3 unlock_initdata.py ${aws_region}"""
        }
      }
    }
  }
}

/* vim:set filetype=groovy ts=2 sw=2 et: */
