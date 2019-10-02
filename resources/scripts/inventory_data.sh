#!/bin/bash

for REGION in us-east-1 us-east-2 us-west-2 ap-northeast-2 eu-north-1 ; do
	echo $REGION
	aws dynamodb --profile=spacemesh --region=$REGION scan --table-name testnet-initdata.$REGION.spacemesh.io |\
		jq '.Items[].space.N' | sort | uniq -c
done
