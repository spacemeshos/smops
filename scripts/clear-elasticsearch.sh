#!/bin/bash

kubectl --context=mgmt-us-east-1 delete pod -n logging -l app=fluent-bit-buffer
curl -X DELETE "https://vpc-testnet-logs-us-east-1-yoijtoajfbbgaiwdf5lcnykl7q.us-east-1.es.amazonaws.com/kubernetes_cluster-*"
