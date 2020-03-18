#!/bin/bash

POET_IDS=$(aws ec2 describe-instances \
  --filter \
    "Name=instance-state-name,Values=running" \
    "Name=tag-key,Values=k8s.io/cluster-autoscaler/node-template/label/pool" \
    "Name=tag-value,Values=poet" \
  --query \
    'Reservations[*].Instances[*].InstanceId' \
  --output text | tr '\n' ' ')

if [[ ! -z "$POET_IDS" ]]; then
  aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name spacemesh-testnet-mgmt-us-east-1-poet \
    --region us-east-1 \
    --desired-capacity 0
  aws ec2 terminate-instances --instance-ids $POET_IDS
fi