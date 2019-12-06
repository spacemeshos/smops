#!/bin/bash

get_spacemesh_configmap_manifest() {
  local cluster=$1
  local region=$2

  # Output header and common content
  cat <<EOF
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: spacemesh-${cluster}
  namespace: default
data:
  initdata_dynamodb_region: ${region}
  initdata_dynamodb_table: testnet-initdata.${region}.spacemesh.io
  initdata_s3_bucket: testnet-initdata.${region}.spacemesh.io
  initdata_s3_prefix: ""
EOF

  # Output miner-specific values
  if [ "$cluster" == "miner" ] ; then
    cat <<EOF
  poet_url: "${SPACEMESH_POET_URL}"
  spacemesh_coinbase: "${SPACEMESH_COINBASE}"
EOF

  fi
}

# vim:set ts=2 sw=2 ai et:
