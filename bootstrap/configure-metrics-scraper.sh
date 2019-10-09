#!/bin/bash

REGION=$1
CLUSTER=$2
IMAGE=534354616613.dkr.ecr.us-east-1.amazonaws.com/spacemesh-testnet-metrics-scraper:latest

if [ -z "$REGION" -o -z "$CLUSTER" ] ; then
    echo "Usage: $0 REGION mgmt|initfactory|miner"
    exit 1
fi

CTX="$CLUSTER-$REGION"
echo "Updating metrics scraper in $CTX"

kubectl --context=$CTX apply -f ./common/spacemesh-metrics-scraper.yml

cat <<EOF | kubectl --context=$CTX apply -f -
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: spacemesh-metrics-scraper
  name: spacemesh-metrics-scraper
  namespace: logging
spec:
  selector:
    matchLabels:
      app: spacemesh-metrics-scraper
  template:
    metadata:
      labels:
        app: spacemesh-metrics-scraper
      annotations:
        fluentbit.io/exclude: "true"
    spec:
      nodeSelector:
        pool: master
      restartPolicy: Always
      serviceAccount: spacemesh-metrics-scraper

      containers:
      - name: default
        env:
        - name: SPACEMESH_SCRAPE_TYPE
          value: $CLUSTER
        - name: SPACEMESH_SCRAPE_REGION
          value: $REGION
        image: $IMAGE
EOF

# vim:set ts=4 sw=4 ai et:
