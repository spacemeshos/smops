#!/bin/bash

CONTEXT=mgmt-us-east-1
POET_URL="spacemesh-testnet-poet-grpc-lb-949d0cde858743fb.elb.us-east-1.amazonaws.com:50002"
COINBASE="0x1234"

MANIFEST=$(mktemp)

echo "Generating config map"
cat <<EOF | tee $MANIFEST
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: initfactory
data:
  poet_url: ${POET_URL}
  poet_nodeaddr: ""
  spacemesh_coinbase: "${COINBASE}"
EOF

echo "Applying config map"
kubectl --context $CONTEXT apply -f $MANIFEST

# vim:set ts=4 sw=4 ai et:
