#!/bin/bash

MINER_IDS=$(aws ec2 describe-instances \
  --filter \
    "Name=instance-state-name,Values=running" \
    "Name=tag-key,Values=k8s.io/cluster-autoscaler/node-template/label/pool" \
    "Name=tag-value,Values=miner" \
  --query \
    'Reservations[*].Instances[*].InstanceId' \
  --output text | tr '\n' ' ')

if [[ ! -z "$MINER_IDS" ]]; then
  for zone in ap-northeast-2 eu-north-1 us-east-1 us-east-2 us-west-2; do
    aws autoscaling update-auto-scaling-group \
      --auto-scaling-group-name spacemesh-testnet-miner-${zone}-miner \
      --region ${zone} \
      --desired-capacity 0
  done
  aws ec2 terminate-instances --instance-ids $MINER_IDS
fi