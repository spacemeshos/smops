#!/bin/bash

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

for role in "$@" ; do
    cat <<EOF
    - rolearn: ${role}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
EOF
done

# vim:set ts=4 sw=4 ai et:
