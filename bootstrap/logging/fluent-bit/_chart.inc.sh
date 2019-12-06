# Chart parameters
RELEASENAME=fluent-bit
NAMESPACE=logging
CHART_NAME=stable/fluent-bit
CHART_VERSION=2.7.0
CHART_VALUES=-


get_values() {
  local cluster=$1
  local region=$2

  local logpath pool

  # Add input file selection
  case "$cluster" in
      miner)
          logpath='/var/log/containers/miner-*.log'
          pool="miner"
          ;;
      initfactory)
          logpath='/var/log/containers/initfactory-*.log'
          pool="initfactory"
          ;;
      mgmt)
          logpath='/var/log/containers/poet-*.log'
          pool="poet"
          ;;
      *)
          logpath='/var/log/containers/*.log'
          pool=""
          ;;
  esac

  cat <<EOF
backend:
  type: forward
  forward:
    host: $FB_FORWARD_HOST
    port: $FB_FORWARD_PORT

input:
  tail:
    path: $logpath
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
        Record spacemesh_cluster ${cluster}-${region}
EOF

[ -n "$pool" ] && cat <<EOF
tolerations:
- key: dedicated
  operator: Equal
  value: $pool
  effect: NoSchedule
nodeSelector:
  pool: $pool
EOF

}

# vim: ts=2 sw=2 et ai:
