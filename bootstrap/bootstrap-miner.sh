#!/bin/bash

REGION=$1
CLUSTER=spacemesh-testnet-miner-$REGION
ROLE_TPL="arn:aws:iam::534354616613:role/$CLUSTER"
CONTEXT="miner-$REGION"
kubectl="kubectl --context=$CONTEXT"
helm="helm --kube-context=$CONTEXT"

if [ -z "$REGION" ] ; then
    echo "Specify the region!"
    exit 1
fi

echo "Working on $CLUSTER in $REGION (ctx $CONTEXT)"

echo "Testing connectivity"
$kubectl version >/dev/null || exit 1

echo "Installing common parts"
$kubectl create -f ./common/ -f ./common/metrics-server/

echo "Adding cluster-autoscaler deployment"
. ./cluster-autoscaler-tpl.sh $CLUSTER | $kubectl create -f -

echo "Creating aws-auth ConfigMap"
. ./aws-auth-map.sh $ROLE_TPL-{master,miner}-node | $kubectl create -f -

echo "Creating 'logging' namespace for Fluent Bit"
$kubectl create namespace logging

echo "Installing helm"
$kubectl create serviceaccount tiller -n kube-system
$kubectl create clusterrolebinding tiller-cluster-admin \
         --serviceaccount=kube-system:tiller \
         --clusterrole=cluster-admin

set -e
$helm init --service-account tiller

echo "Waiting for tiller to start..."
$kubectl wait deploy/tiller-deploy --for condition=Available -n kube-system --timeout=600s
$kubectl wait pod -l app=helm --for condition=Ready -n kube-system --timeout=600s

echo "Installing Fluent Bit with Helm"
. helm-values-fluent-bit.sh $CONTEXT |\
    $helm install stable/fluent-bit \
          -n fluent-bit \
          --namespace logging \
          -f -

# vim:set ts=4 sw=4 ai et:
