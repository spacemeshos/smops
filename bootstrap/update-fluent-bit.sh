#!/bin/bash

REGION=$1
CLUSTER_ID=$2

if [ -z "$REGION" -o -z "$CLUSTER_ID" ] ; then
    echo "Usage: $0 <REGION> mgmt|initfactory|miner"
    exit 1
fi

echo "Loading config"
. $(dirname $0)/_config.inc.sh || exit 2

POOL_LIST=${POOLS[$CLUSTER_ID]}
if [ -z "$POOL_LIST" ] ; then
    echo "No pool definitions for '$CLUSTER_ID' found"
    exit 3
fi

CLUSTER=spacemesh-testnet-$CLUSTER_ID-$REGION
CONTEXT="$CLUSTER_ID-$REGION"
kubectl="kubectl --context=$CONTEXT"
helm="helm --kube-context=$CONTEXT"

echo "Working on $CLUSTER in $REGION (ctx $CONTEXT)"

echo "Updating Fluent Bit with Helm"
. helm-values-fluent-bit.sh $CONTEXT $POOL_LIST |\
    $helm upgrade fluent-bit stable/fluent-bit -f -

# vim:set ts=4 sw=4 ai et:
