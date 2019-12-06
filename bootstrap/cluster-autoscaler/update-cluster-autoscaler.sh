#!/bin/bash

# Fail on first error
set -e

# Change to script directory
cd $(dirname $0)

# Load global configuration
source ../_config.inc.sh

# Load ConfigMap template
source ./_cluster-autoscaler-deploy.tpl.sh

update_cluster_autoscaler() {
  local c_type=$1
  local c_region=$2
  local context=${c_type}-${c_region}

  case "$c_type" in
    miner|initfactory)
      echo "Updating cluster-autoscaler in $context"
      get_deployment_manifest $context | kubectl --context=$context apply -f - -f ./cluster-autoscaler-common.yml
      ;;
    *)
      echo "Invalid cluster type $c_type"
      exit 1
      ;;
  esac
}

if [ "$1" == "--help" -o "$1" == "-h" ] ; then
  cat <<EOF
Upgrade cluster-autoscaler in clusters

Usage: $0 [<type> [<region> ...]]

Cluster <type> can be initfactory or miner.
EOF

  exit 0
fi

CLUSTERS="miner initfactory"
if [ $# -gt 0 ] ; then
  CLUSTERS=$1
  shift

  if [ $# -gt 0 ] ; then
    REGIONS="$@"
  fi
fi

for c_type in $CLUSTERS ; do
  echo "Updating $c_type clusters in $REGIONS"
  for c_region in $REGIONS ; do
    update_cluster_autoscaler $c_type $c_region
  done
done

# vim: ts=2 sw=2 et ai:
