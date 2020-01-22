#!/bin/bash

get_configmap_manifest() {
  local c_type=$1
  local c_region=$2

  cat <<EOF
---
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: logging
  name: fluent-bit-master
data:
  spacemesh_cluster: ${c_type}-${c_region}
  aws_region: ${c_region}
  fluent-bit.conf: |
    [SERVICE]
        Daemon       Off
        Flush        1
        Log_Level    info
        Parsers_file parsers.conf
        Plugins_file plugins.conf
        HTTP_Server  Off

    [INPUT]
        Name             tail
        Path             /var/log/containers/*.log
        Parser           docker
        Tag              master.<filename>
        Tag_Regex        /(?<filename>[^/]+)$
        Refresh_Interval 5
        Mem_Buf_Limit    5MB
        Skip_Long_Lines  On

    [OUTPUT]
        Name              cloudwatch
        Match             *
        Region            \${AWS_REGION}
        Log_Group_Name    spacemesh-testnet-\${SPACEMESH_CLUSTER}
        Log_Stream_Prefix eks-

    [FILTER]
        Name                kubernetes
        Match               master.*
        Kube_Tag_Prefix     master.
        Kube_URL            https://kubernetes.default.svc:443
        Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
        Merge_Log           On
        K8S-Logging.Parser  On
        K8S-Logging.Exclude On
EOF

}

# vim:ts=2 sw=2 et:
