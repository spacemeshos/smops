#!/bin/bash

REGIONS="ap-northeast-2 eu-north-1 us-east-1 us-east-2 us-west-2"

POET_URL="spacemesh-testnet-poet-grpc-lb-949d0cde858743fb.elb.us-east-1.amazonaws.com:50002"
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
  poet_url: ${POET_URL}
  poet_nodeaddr: ""
  spacemesh_coinbase: "${COINBASE}"
EOF

    for CONTEXT in {initfactory,miner}-$REGION ; do
        echo "Applying to $CONTEXT"
        kubectl --context $CONTEXT apply -f $MANIFEST
    done
done

# vim:set ts=4 sw=4 ai et:
