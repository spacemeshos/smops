/*
  initfactory Inventory

  Example:

    @Library("spacemesh") _
    initfactoryInventory()
*/

def call() {
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
          writeFile file: "inventory_data.py", text: libraryResource("scripts/inventory_data.py")
        }
      }

      stage("Inventory data") {
        steps {
          sh """python3 inventory_data.py > index.html"""
        }
      }

      stage("Archive") {
	steps {
	  archiveArtifacts "index.html"
	}
      }
    }
  }
}

/* vim:set filetype=groovy ts=2 sw=2 et: */
