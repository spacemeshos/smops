REGIONS="ap-northeast-2 eu-north-1 us-east-1 us-east-2 us-west-2"
MGMT_REGION="us-east-1"

declare -A POOLS
POOLS[miner]="master miner"
POOLS[initfactory]="master initfactory"
POOLS[mgmt]="master poet logging"
