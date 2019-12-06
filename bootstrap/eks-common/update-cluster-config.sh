#!/bin/bash

# Show help
if [ "$1" == "--help" -o "$1" == "-h" ] ; then
  cat <<EOF
Update common EKS Cluster configuration

Usage: $0 [<type> [<region> ...]]

Cluster <type> can be initfactory, miner or mgmt.
EOF

  exit 0
fi

# Fail on first error
set -e

# Change to script directory
cd $(dirname $0)

# Load global configuration
source ../_config.inc.sh

# Load aws-auth ConfigMap template
source ./_aws-auth-configmap.tpl.sh

# Update a single cluster config
update_cluster_config() {
  local cluster=$1
  local region=$2
  local context=$cluster-$region
  local kubectl="kubectl --context=$context"

  echo " >>> Updating $cluster cluster in $region (context $context)"

  echo "Checking connectivity"
  $kubectl version > /dev/null

  echo "Creating/updating ConfigMap/aws-auth"
  get_aws_auth_configmap_manifest $cluster $region | $kubectl apply -f -

  echo "Creating/updating StorageClass/gp2-delayed"
  $kubectl apply -f gp2-delayed-storageclass.yml

  echo "Installing/updating metrics-server"
  $kubectl apply -f ./metrics-server/

  echo "Installing/updating helm: ServiceAccount"
  $kubectl apply -f tiller.yml
  echo "Installing/updating helm: tiller"
  helm --kube-context=$context init --service-account tiller --upgrade
  echo "Installing/updating helm: waiting for tiller to start"
  # Pod to be scheduled
  $kubectl wait deploy/tiller-deploy --for=condition=Available -n kube-system
  # Pod to become ready
  $kubectl wait pod -l app=helm --for condition=Ready -n kube-system --timeout=600s
}

if [ $# -eq 0 ] ; then
  echo "Working on all clusters"
  CLUSTERS="mgmt initfactory miner"
else
  CLUSTERS=$1
  shift
  if [ "$CLUSTERS" == "mgmt" ] ; then
    REGIONS=$MGMT_REGION
  elif [ $# -gt 0 ] ; then
    REGIONS=$@
  fi
  echo "Working on $CLUSTERS cluster in $REGIONS"
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
