# All the regions covered by TestNet
REGIONS="ap-northeast-2 eu-north-1 us-east-1 us-east-2 us-west-2"

# Region where management infrastructure resides
MGMT_REGION="us-east-1"

# Common spacemesh configuration parameters
SPACEMESH_COINBASE="0x1234"
SPACEMESH_POET_URL="poet-testnet.spacemesh.io:8080"

# Logging infrastructure parameters
LOGS_ES_HOST="vpc-testnet-logs-us-east-1-yoijtoajfbbgaiwdf5lcnykl7q.us-east-1.es.amazonaws.com"
LOGS_ES_PORT="80"
LOGS_ES_URL="https://vpc-testnet-logs-us-east-1-yoijtoajfbbgaiwdf5lcnykl7q.us-east-1.es.amazonaws.com"

FB_FORWARD_HOST="spacemesh-testnet-mgmt-fb-fwd-lb-8e14e7d176466555.elb.us-east-1.amazonaws.com"
FB_FORWARD_PORT=24224

# Node pools for each cluster type
declare -A POOLS
POOLS[miner]="master miner"
POOLS[initfactory]="master initfactory"
POOLS[mgmt]="master poet logging"
