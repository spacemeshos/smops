#!/bin/sh

ES_HOST=http://internal-spacemesh-testnet-mgmt-es-116988061.us-east-1.elb.amazonaws.com:9200

curl="curl -sS -H content-type:application/json"

echo "Creating ingest_timestamp_pipeline"
$curl -XPUT $ES_HOST"/_ingest/pipeline/ingest_timestamp_pipeline?pretty" -d \
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

echo "Creating index_delete lifecycle policy"
$curl -XPUT $ES_HOST"/_ilm/policy/index_delete?pretty" -d \
'{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {}
      },
      "warm": {
        "min_age": "1d",
        "actions": {"readonly":{}, "shrink": {"number_of_shards": "1"}}
      },
      "cold": {
        "min_age": "2d",
        "actions": {"freeze": {}}
      },
      "delete": {
        "min_age": "7d",
        "actions": {"delete": {}}
      }
    }
  }
}'

echo "Creating kubernetes_cluster_template"
$curl -XPUT $ES_HOST"/_template/kubernetes_cluster_template?pretty" -d \
'{
  "index_patterns": ["kubernetes_cluster-*"],
  "settings": {
    "index": {
      "refresh_interval": "30s",
      "number_of_shards": "3",
      "number_of_replicas": "0",
      "default_pipeline": "ingest_timestamp_pipeline",
      "translog": { "durability": "async" },
      "lifecycle": {
        "name": "index_delete",
        "rollover_alias": ""
      }
    }
  }
}'

echo "Adjusting global settings"
$curl -XPUT $ES_HOST"/_settings?pretty" -d \
'{
  "index.translog.durability": "async",
  "index.blocks.read_only_allow_delete": null
}'

# vim: set ts=4 sw=4 et ai:
