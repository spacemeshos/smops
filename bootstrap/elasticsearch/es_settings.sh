#!/bin/sh

ES_HOST=http://internal-spacemesh-testnet-mgmt-es-116988061.us-east-1.elb.amazonaws.com:9200


curl -i -XPUT -H "content-type: application/json" $ES_HOST"/_ingest/pipeline/ingest_timestamp_pipeline" -d '
{
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

curl -i -H "content-type: application/json" $ES_HOST"/_template/kubernetes_cluster_template" -d '
{
    "index_patterns" : [
      "kubernetes_cluster-*"
    ],
    "settings" : {
      "index" : {
          "refresh_interval" : "5s",
          "number_of_replicas" : 0,
          "default_pipeline": "ingest_timestamp_pipeline",
          "translog" : {
            "durability" : "async"
          },
          "lifecycle" : {
            "name" : "index_delete",
            "rollover_alias" : ""
          }
      }
    }
}'

curl -i -XPUT -H "content-type: application/json" $ES_HOST"/_settings" -d '
{
  "index.translog.durability" : "async",
  "index.blocks.read_only_allow_delete": null
}'
