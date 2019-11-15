/*
  initfactory Inventory

  Example:

    @Library("spacemesh") _
    initfactoryInventory()
*/

def call() {

    regionList = ['us-east-1', 'us-east-2', 'us-west-2', 'ap-northeast-2', 'eu-north-1']

    /*
        PIPELINE
    */

    pipeline {
        agent any

        stages {
            stage('Inventory') {
                steps {
                    withAWS(credentials:'aws') {
                        script {
                            sh(returnStdout: true, script: 'echo " " > initFiles.txt').trim()
                            for (int i = 0; i < regionList.size(); i++) {
                                sh """
                                    echo ${regionList[i]} >> initFiles.txt
                                    echo "==============="
                                    aws dynamodb --region=${regionList[i]} scan --table-name testnet-initdata.${regionList[i]}.spacemesh.io |\
                                        jq '.Items[].space.N' | sort | uniq -c >> initFiles.txt
                                    echo " " >> initFiles.txt
                                """
                            }
                        }
                    }
                }
            }
        }
        post {
            always {
                archiveArtifacts artifacts: 'initFiles.txt', onlyIfSuccessful: true
            }
        }
    }
}
