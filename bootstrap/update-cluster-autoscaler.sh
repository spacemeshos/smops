#!/bin/bash

REGION=$1

_update() {
    CLUSTER=$1
    echo "Updating cluster-autoscaler in $CLUSTER"
    kubectl="kubectl --context=$CLUSTER"

    . ./cluster-autoscaler-tpl.sh $CLUSTER | $kubectl apply -f -
}

_update initfactory-$REGION
_update miner-$REGION

# vim:set ts=4 sw=4 ai et:
