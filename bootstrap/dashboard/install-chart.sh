#!/bin/bash

# Fail on first error
set -e

# Change to script directory
cd $(dirname $0)

# Load global configuration
source ../_config.inc.sh

# Load chart parameters
source _chart.inc.sh

install_chart() {
  CTX=$1
  echo "Working in $CTX"
  helm="command helm --kube-context=$CTX"

  echo "Installing $RELEASENAME from $CHART_NAME:$CHART_VERSION"
  $helm install --name $RELEASENAME --namespace $NAMESPACE \
                --values ${CHART_VALUES:-values.yaml} \
                $CHART_NAME --version $CHART_VERSION
}

if [ -n "$1" ] ; then
  # Working in contexts listed on command line
  for ctx in $@ ; do
    install_chart $ctx
  done
else
  # Working in all contexts
  for reg in $REGIONS ; do for cluster in initfactory miner ; do
    install_chart "$cluster-$reg"
  done ; done
fi

# vim: ts=2 sw=2 et ai:
