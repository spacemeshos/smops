#!/bin/bash

# Fail on first error
set -e

# Change to script directory
cd $(dirname $0)

# Load global configuration
source ../../_config.inc.sh

# Load ConfigMap template
source ./_fb-master-config.tpl.sh

update_fb_master() {
  local c_type=$1
  local c_region=$2
  local context=${c_type}-${c_region}

  case "$c_type" in
    mgmt)
      echo "Updating Fluent Bit / CloudWatch in MGMT mode in $context"
      kubectl --context=$context apply -f ./mgmt/
      ;;
    miner|initfactory)
      echo "Updating Fluent Bit / CloudWatch in Miner/InitFactory mode in $context"
      get_configmap_manifest $c_type $c_region | kubectl --context=$context apply -f - -f ./fb-master-daemonset.yml
      ;;
    *)
      echo "Invalid cluster type $c_type"
      exit 1
      ;;
  esac
}

if [ "$1" == "--help" -o "$1" == "-h" ] ; then
  cat <<EOF
Upgrade Fluent Bit in on cluster's master nodes

Usage: $0 [<type> [<region> ...]]

Cluster <type> can be initfactory, miner or mgmt.

NB: mgmt also has Fluent Bit deployed on logging pool nodes.
EOF

  exit 0
fi

CLUSTER=""
if [ $# -gt 0 ] ; then
  CLUSTER=$1
  shift

  if [ $# -gt 0 ] ; then
    REGIONS="$@"
  fi
fi

if [ -z "$CLUSTER" ] ; then
  echo "Updating MGMT cluster in $MGMT_REGION"
  update_fb_master mgmt $MGMT_REGION

  for c_type in miner initfactory ; do
    echo "Updating $c_type clusters in $REGIONS"
    for c_region in $REGIONS ; do
      update_fb_master $c_type $c_region
    done
  done
elif [ "$CLUSTER" == "mgmt" ] ; then
  echo "Updating MGMT cluster in $MGMT_REGION"
  update_fb_master mgmt $MGMT_REGION
else
  echo "Updating $CLUSTER in $REGIONS"
  for c_region in $REGIONS ; do
    update_fb_master $CLUSTER $c_region
  done
fi

# vim: ts=2 sw=2 et ai:
