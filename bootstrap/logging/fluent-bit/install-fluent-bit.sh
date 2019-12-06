#!/bin/bash

# Fail on first error
set -e

# Change to script directory
cd $(dirname $0)

# Load global configuration
source ../../_config.inc.sh

# Load chart parameters
source _chart.inc.sh

# Install chart
install_chart() {
  CTX=$1
  echo "Working in $CTX"
  helm="command helm --kube-context=$CTX"

  echo "Installing $RELEASENAME from $CHART_NAME:$CHART_VERSION"
  $helm install --name $RELEASENAME --namespace $NAMESPACE \
                --values ${CHART_VALUES:-values.yaml} \
                $CHART_NAME --version $CHART_VERSION
}

if [ -n "$1" -a -n "$2" ] ; then
  cluster=$1
  shift

  # Working in the regions listed on command line
  for region in $@ ; do
    get_values $cluster $region | install_chart $cluster-$region
  done
else
  cat <<EOF
Install Fluent Bit in the clusters

Usage: $0 [<type> <region> ...]

Cluster <type> can be initfactory, miner or mgmt.
EOF

fi

# vim: ts=2 sw=2 et ai:
