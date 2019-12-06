#!/bin/bash

get_metrics_scraper_deploy_manifest() {
  local cluster=$1
  local region=$2

  # FIXME: Move to Docker Hub
  local IMAGE=534354616613.dkr.ecr.us-east-1.amazonaws.com/spacemesh-testnet-metrics-scraper:latest

  # Output header and common content
  cat <<EOF
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
    spec:
      nodeSelector:
        pool: master
      restartPolicy: Always
      serviceAccount: spacemesh-metrics-scraper

      containers:
      - name: default
        env:
        - name: SPACEMESH_SCRAPE_TYPE
          value: $cluster
        - name: SPACEMESH_SCRAPE_REGION
          value: $region
        image: $IMAGE
EOF

}

# vim:set ts=2 sw=2 ai et:
