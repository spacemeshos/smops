#!/bin/bash

# Show help
if [ "$1" == "--help" -o "$1" == "-h" ] ; then
  cat <<EOF
Update spacemesh ConfigMap

Usage: $0 [<type> [<region> ...]]

Cluster <type> can be initfactory or miner.
EOF

  exit 0
fi

# Fail on first error
set -e

# Change to script directory
cd $(dirname $0)

# Load global configuration
source ../_config.inc.sh

# Load spacemesh ConfigMap template
source ./_spacemesh-configmap.tpl.sh

# Update a single cluster config
update_cluster_config() {
  local cluster=$1
  local region=$2
  local context=$cluster-$region
  local kubectl="kubectl --context=$context"

  echo " >>> Updating $cluster cluster in $region (context $context)"

  echo "Installing/updating ConfigMap/spacemesh-${cluster}"
  get_spacemesh_configmap_manifest $cluster $region | $kubectl apply -f -
}

if [ $# -eq 0 ] ; then
  echo "Working on all clusters"
  CLUSTERS="initfactory miner"
else
  CLUSTERS=$1
  shift
  if [ $# -gt 0 ] ; then
    REGIONS=$@
  fi
  echo "Working on $CLUSTERS cluster(s) in $REGIONS"
fi

for c_type in $CLUSTERS ; do
  if [ "$c_type" == "mgmt" ] ; then
    update_cluster_config mgmt $MGMT_REGION
  else
    for c_region in $REGIONS ; do
      update_cluster_config $c_type $c_region
    done
  fi
done

# vim: ts=2 sw=2 et ai:
