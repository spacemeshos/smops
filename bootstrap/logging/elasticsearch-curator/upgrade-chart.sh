#!/bin/bash

# Fail on first error
set -e

# Change to script directory
cd $(dirname $0)

# Load global configuration
source ../../_config.inc.sh

# Load chart parameters
source _chart.inc.sh

upgrade_chart() {
  CTX=$1
  echo "Working in $CTX"
  helm="command helm --kube-context=$CTX"

  echo "Upgrading $RELEASENAME from $CHART_NAME:$CHART_VERSION"
  $helm upgrade $RELEASENAME $CHART_NAME --version $CHART_VERSION $CHART_EXTRA_ARGS \
                                         --values ${CHART_VALUES:-values.yaml}
}

upgrade_chart mgmt-us-east-1

# vim: ts=2 sw=2 et ai:
