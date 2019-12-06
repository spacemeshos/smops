#!/bin/bash

get_aws_auth_configmap_manifest() {
  local role_base="arn:aws:iam::534354616613:role/spacemesh-testnet"
  local cluster=$1
  local region=$2

  # Output header
  cat <<EOF
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
EOF

  # Output a mapping for each node pool
  for pool in ${POOLS[$cluster]} ; do
    cat <<EOF
    - rolearn: ${role_base}-${cluster}-${region}-${pool}-node
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
EOF

  done
}

# vim:set ts=2 sw=2 ai et:
