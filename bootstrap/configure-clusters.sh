#!/bin/bash

REGIONS="ap-northeast-2 eu-north-1 us-east-1 us-east-2 us-west-2"

declare -A POET
POET["ap-northeast-2"]="spacemesh-testnet-poet-grpc-lb-8f4a4fc1729801b2.elb.ap-northeast-2.amazonaws.com:50002"
POET["eu-north-1"]="spacemesh-testnet-poet-grpc-lb-a390c50a80ea4435.elb.eu-north-1.amazonaws.com:50002"
POET["us-east-1"]="spacemesh-testnet-poet-grpc-lb-6a3ace93a4d7c65d.elb.us-east-1.amazonaws.com:50002"
POET["us-east-2"]="spacemesh-testnet-poet-grpc-lb-01b0da360834b7eb.elb.us-east-2.amazonaws.com:50002"
POET["us-west-2"]="spacemesh-testnet-poet-grpc-lb-526f896bbc911d0e.elb.us-west-2.amazonaws.com:50002"

COINBASE="0x1234"

MANIFEST=$(mktemp)

for REGION in $REGIONS ; do
    echo "Generating config map for $REGION"
    cat <<EOF | tee $MANIFEST
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: initfactory
data:
  initdata_dynamodb_region: $REGION
  initdata_dynamodb_table: testnet-initdata.${REGION}.spacemesh.io
  initdata_s3_bucket: testnet-initdata.${REGION}.spacemesh.io
  initdata_s3_prefix: ""
  poet_url: ${POET[$REGION]}
  poet_nodeaddr: ""
  spacemesh_coinbase: "${COINBASE}"
EOF

    for CONTEXT in {initfactory,miner}-$REGION ; do
        echo "Applying to $CONTEXT"
        kubectl --context $CONTEXT apply -f $MANIFEST
    done
done

# vim:set ts=4 sw=4 ai et:
