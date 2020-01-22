# Chart parameters
RELEASENAME=es-curator
NAMESPACE=logging
CHART_NAME=stable/elasticsearch-curator
CHART_VERSION=2.1.3
CHART_VALUES=values.yaml
CHART_EXTRA_ARGS="--set env.LOGS_ES_HOST=$LOGS_ES_HOST,env.LOGS_ES_PORT=$LOGS_ES_PORT"
