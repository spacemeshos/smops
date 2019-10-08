#!/bin/sh

ECR=534354616613.dkr.ecr.us-east-1.amazonaws.com/spacemesh-testnet-metrics-scraper

echo "Tagging image"
docker tag spacemeshos-metrics-scraper:latest $ECR

echo "Pushing to ECR"
docker push $ECR || {
	echo "Maybe login has expired?"
	$(aws --profile=spacemesh ecr get-login --no-include-email --region us-east-1)
	docker push $ECR
}
