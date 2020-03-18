#!/bin/bash
set -e

# kubectl --context=miner-us-east-1 delete deployments,svc -l app=config-toml
echo "Delete pods"
kubectl config get-contexts -o name | \
  grep 'miner\|mgmt' | \
  xargs -I {} -n 1 -P 10 kubectl --context={} delete svc,deploy,pvc,statefulset -l "app in (miner, poet)" -n default

echo "Terminate VM's"
./scripts/terminate-miners.sh
./scripts/terminate-poets.sh

echo "Cleanup Jenkins"
./scripts/cleanup-jenkins.sh

echo "Clear Elasticsearch"
./scripts/clear-elasticsearch.sh
