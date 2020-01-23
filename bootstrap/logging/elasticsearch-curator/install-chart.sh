#!/bin/bash

# Fail on first error
set -e

# Change to script directory
cd $(dirname $0)

# Load global configuration
source ../../_config.inc.sh

# Load chart parameters
source _chart.inc.sh

install_chart() {
  CTX=$1
  echo "Working in $CTX"
  helm="command helm --kube-context=$CTX"

  echo "Installing $RELEASENAME from $CHART_NAME:$CHART_VERSION"
  $helm install --name $RELEASENAME --namespace $NAMESPACE \
                --values ${CHART_VALUES:-values.yaml} \
                $CHART_EXTRA_ARGS \
                $CHART_NAME --version $CHART_VERSION
}

install_chart mgmt-us-east-1

# vim: ts=2 sw=2 et ai:
