# Chart parameters
RELEASENAME=fluent-bit
NAMESPACE=logging
CHART_NAME=stable/fluent-bit
CHART_VERSION=2.7.0
CHART_VALUES=-

FORWARD_HOST="spacemesh-testnet-mgmt-fb-fwd-lb-8e14e7d176466555.elb.us-east-1.amazonaws.com"
FORWARD_PORT=24224

get_values() {
  CLUSTER=$1
  REGION=$2

  # Add input file selection
  case "$CLUSTER" in
      miner)
          LOGPATH='/var/log/containers/miner-*.log'
          POOL="miner"
          ;;
      initfactory)
          LOGPATH='/var/log/containers/initfactory-*.log'
          POOL="initfactory"
          ;;
      mgmt)
          LOGPATH='/var/log/containers/poet-*.log'
          POOL="poet"
          ;;
      *)
          LOGPATH='/var/log/containers/*.log'
          POOL=""
          ;;
  esac

  cat <<EOF
backend:
  type: forward
  forward:
    host: $FORWARD_HOST
    port: $FORWARD_PORT

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
        Record spacemesh_cluster ${CLUSTER}-${REGION}
EOF

[ -n "$POOL" ] && cat <<EOF
tolerations:
- key: dedicated
  operator: Equal
  value: $POOL
  effect: NoSchedule
nodeSelector:
  pool: $POOL
EOF

}

# vim: ts=2 sw=2 et ai:
