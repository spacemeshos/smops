#!/bin/sh

# Load common configuration
source $(dirname $0)/../../_config.inc.sh

curl="curl -sS -H content-type:application/json"

echo "Creating ingest_timestamp_pipeline"
$curl -XPUT $LOGS_ES_URL"/_ingest/pipeline/ingest_timestamp_pipeline?pretty" -d \
'{
  "description": "Adds a field to a document with the time of ingestion",
  "processors": [
    {
      "set": {
        "field": "ingest_timestamp",
        "value": "{{_ingest.timestamp}}"
      }
    }
  ]
}'

echo "Creating kubernetes_cluster_template"
$curl -XPUT $LOGS_ES_URL"/_template/kubernetes_cluster_template?pretty" -d \
'{
  "index_patterns": ["kubernetes_cluster-*"],
  "settings": {
    "index": {
      "default_pipeline": "ingest_timestamp_pipeline",
      "number_of_replicas": "0"
    }
  }
}'

# vim: set ts=4 sw=4 et ai:
