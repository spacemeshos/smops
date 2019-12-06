# All the regions covered by TestNet
REGIONS="ap-northeast-2 eu-north-1 us-east-1 us-east-2 us-west-2"

# Region where management infrastructure resides
MGMT_REGION="us-east-1"

# Common spacemesh configuration parameters
SPACEMESH_COINBASE="0x1234"
SPACEMESH_POET_URL="poet-testnet.spacemesh.io:50002"

# Logging infrastructure parameters
LOGS_ES_HOST=http://internal-spacemesh-testnet-mgmt-es-116988061.us-east-1.elb.amazonaws.com:9200
FB_FORWARD_HOST="spacemesh-testnet-mgmt-fb-fwd-lb-8e14e7d176466555.elb.us-east-1.amazonaws.com"
FB_FORWARD_PORT=24224

# Node pools for each cluster type
declare -A POOLS
POOLS[miner]="master miner"
POOLS[initfactory]="master initfactory"
POOLS[mgmt]="master poet logging"
