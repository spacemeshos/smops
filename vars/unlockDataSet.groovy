def call(aws_region="us-east-2") {
  /* Pipeline-global variables */
  def items = []
  
  /*
    PIPELINE
   */
  pipeline {
    options {
      buildDiscarder(logRotator(numToKeepStr: '10')) // Keep last 10 builds only
    }

    agent any

    stages {
      stage("List items") {
        steps {
          script {
            items = shell("""\
              aws dynamodb --region=${aws_region} scan \\
                           --table-name testnet-initdata.${aws_region}.spacemesh.io \\
                           --projection-expression 'id' \\
                           --query 'Items[].id.S' \\
                           --output text
                           """.stripIndent()
                         ).split()
          }
          echo "Found ${items.size()} item(s) to unlock"
        }
      }

      stage("Unlock") {
        steps {
          script {
            items.each {
              sh """\
                aws dynamodb --region=${aws_region} update-item \\
                             --table-name testnet-initdata.${aws_region}.spacemesh.io \\
                             --key '{"id": {"S": "${it}"}}' \\
                             --update-expression 'SET locked=:false REMOVE locked_by' \\
                             --expression-attribute-values '{":false": {"N": "0"}}'
                """.stripIndent()
            }
          }
        }
      }
    }
  }
}

/* vim:set filetype=groovy ts=2 sw=2 et: */
