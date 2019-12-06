#!/bin/bash

# Fail on first error
set -e

# Change to script directory
cd $(dirname $0)

# Load global configuration
source ../../_config.inc.sh

# Load chart parameters
source _chart.inc.sh

# Upgrade chart
upgrade_chart() {
  CTX=$1
  echo "Working in $CTX"
  helm="command helm --kube-context=$CTX"

  echo "Upgrading $RELEASENAME from $CHART_NAME:$CHART_VERSION"
  $helm upgrade $RELEASENAME $CHART_NAME --version $CHART_VERSION \
                                         --values ${CHART_VALUES:-values.yaml}
}

if [ "$1" == "--help" -o "$1" == "-h" ] ; then
  cat <<EOF
Upgrade Fluent Bit in clusters

Usage: $0 [<type> <region> ...]

Cluster <type> can be initfactory, miner or mgmt.
EOF

elif [ -n "$1" ] ; then
  cluster=$1
  shift

  # Working in the regions listed on command line
  for region in $@ ; do
    get_values $cluster $region | upgrade_chart $cluster-$region
  done
else
  # Working in all contexts
  for cluster in initfactory miner ; do for region in $REGIONS ; do
    get_values $cluster $region | upgrade_chart $cluster-$region
  done ; done

  # Upgrade Fluent Bit in mgmt
  get_values mgmt us-east-1 | upgrade_chart mgmt-us-east-1
fi

# vim: ts=2 sw=2 et ai:
