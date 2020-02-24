#!/bin/bash

cd "$(dirname -- "$0")"

kubectl --context=mgmt-us-east-1 apply -f ./ext-lbs/poet-nginx.yaml
kubectl --context=miner-us-east-1 apply -f ./ext-lbs/config-toml-server.yaml
# kubectl --context=miner-us-east-1 apply -f ./ext-lbs/api-nginx.yaml