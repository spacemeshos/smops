#!/bin/bash

# Fail on first error
set -e

# Change to script directory
cd $(dirname $0)

# Load global configuration
source ../_config.inc.sh

# Load chart parameters
source _chart.inc.sh

upgrade_chart() {
  CTX=$1
  echo "Working in $CTX"
  helm="command helm --kube-context=$CTX"

  echo "Upgrading $RELEASENAME from $CHART_NAME:$CHART_VERSION"
  $helm upgrade $RELEASENAME $CHART_NAME --version $CHART_VERSION \
                                         --values ${CHART_VALUES:-values.yaml}
}

if [ -n "$1" ] ; then
  # Working in contexts listed on command line
  for ctx in $@ ; do
    uprade_chart $ctx
  done
else
  # Working in all contexts
  for reg in $REGIONS ; do for cluster in initfactory miner ; do
    upgrade_chart "$cluster-$reg"
  done ; done
fi

# vim: ts=2 sw=2 et ai:
