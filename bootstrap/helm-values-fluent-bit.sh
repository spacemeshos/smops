#!/bin/bash

ELASTICSEARCH_HOST="internal-spacemesh-testnet-mgmt-es-116988061.us-east-1.elb.amazonaws.com"

CONTEXT=$1
shift

cat <<EOF
backend:
  type: es
  es:
    time_key: '@ts'
    host: $ELASTICSEARCH_HOST

podAnnotations:
  fluentbit.io/exclude: "true"

parsers:
  enabled: yes
  regex:
    - name: panic
      regex: "panic*"
      timeKey: time
  json:
    - name: default-json

rawConfig: |
    @INCLUDE fluent-bit-service.conf
    @INCLUDE fluent-bit-input.conf
    @INCLUDE fluent-bit-filter.conf
    @INCLUDE fluent-bit-output.conf

    [FILTER]
        Name record_modifier
        Match *
        Record spacemesh_cluster $CONTEXT

tolerations:
EOF

for pool in "$@"; do
    cat <<EOF
- key: dedicated
  operator: Equal
  value: $pool
  effect: NoSchedule
EOF
done

# vim:set ts=4 sw=4 ai et:
