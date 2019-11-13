#!/bin/bash

#ELASTICSEARCH_HOST="internal-spacemesh-testnet-mgmt-es-116988061.us-east-1.elb.amazonaws.com"
FORWARD_HOST="spacemesh-testnet-mgmt-fb-fwd-lb-8e14e7d176466555.elb.us-east-1.amazonaws.com"
FORWARD_PORT=24224

CONTEXT=$1
shift

# Add input file selection
case "$CONTEXT" in
    miner-*)
        LOGPATH=/var/log/containers/miner-*.log
        ;;
    initfactory-*)
        LOGPATH=/var/log/containers/initfactory-*.log
        ;;
    mgmt-*)
        LOGPATH=/var/log/containers/poet-*.log
        ;;
    *)
        LOGPATH=/var/log/containers/*.log
        ;;
esac

cat <<EOF
backend:
  type: forward
  forward:
    host: $FORWARD_HOST
    port: $FORWARD_PORT

podAnnotations:
  fluentbit.io/exclude: "true"

input:
  tail:
    path: $LOGPATH
parsers:
  enabled: yes
  regex:
    - name: panic
      regex: "panic*"
      timeKey: time
  json:
    - name: default-json

extraEntries:
  output: |
    Generate_ID On

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
