#!/bin/bash

# kubectl --context=miner-us-east-1 apply -f ./scripts/ext-lbs/config-toml-server.yaml
kubectl --context=miner-us-east-1 get service config-toml -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"
