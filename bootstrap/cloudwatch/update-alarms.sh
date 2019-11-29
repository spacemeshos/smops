#!/bin/sh

# Fail on first error
set -e

# Change to script directory
cd $(dirname $0)

# Load global configuration
source ../_config.inc.sh

# Local configuration values
SNS_TOPIC="arn:aws:sns:us-east-1:534354616613:spacemesh-testnet-alarm"

# Template: JSON for dangling volumes alarm
vol_alarm_tpl() {
    REGION=$1
    cat <<EOF
{
  "AlarmName": "Dangling volumes in ${REGION}",
  "AlarmDescription": "There are dangling volumes in ${REGION}",
  "ActionsEnabled": true,
  "OKActions": [],
  "AlarmActions": ["${SNS_TOPIC}"],
  "InsufficientDataActions": [],
  "MetricName": "miner-vol-available",
  "Namespace": "spacemesh/${REGION}",
  "Statistic": "Minimum",
  "Dimensions": [],
  "Period": 900,
  "EvaluationPeriods": 1,
  "DatapointsToAlarm": 1,
  "Threshold": 1,
  "ComparisonOperator": "GreaterThanOrEqualToThreshold",
  "TreatMissingData": "notBreaching"
}
EOF
}

# Template: JSON for no data from scraper alarm
data_alarm_tpl() {
    REGION=$1
    cat <<EOF
{
  "AlarmName": "No data from ${REGION} miner",
  "ActionsEnabled": true,
  "OKActions": [],
  "AlarmActions": ["${SNS_TOPIC}"],
  "InsufficientDataActions": [],
  "MetricName": "miner-master-nodes",
  "Namespace": "spacemesh/${REGION}",
  "Statistic": "SampleCount",
  "Dimensions": [],
  "Period": 3600,
  "EvaluationPeriods": 1,
  "Threshold": 10,
  "ComparisonOperator": "LessThanThreshold",
  "TreatMissingData": "missing"
}
EOF
}

tmp_json=$(mktemp)
echo "Using $tmp_json for AWS CLI input"

# Volume alarms
for region in $REGIONS ; do
    echo "Updating volume alarm in $region"
    vol_alarm_tpl $region >$tmp_json
    aws cloudwatch put-metric-alarm --cli-input-json file://$tmp_json

    echo "Updating no data alarm in $region"
    data_alarm_tpl $region >$tmp_json
    aws cloudwatch put-metric-alarm --cli-input-json file://$tmp_json
done

echo "Removing $tmp_json"
rm -vf $tmp_json

exit
cat <<EOF

{
    "AlarmName": "",
    "AlarmDescription": "",
    "ActionsEnabled": true,
    "OKActions": [
        ""
    ],
    "AlarmActions": [
        ""
    ],
    "InsufficientDataActions": [
        ""
    ],
    "MetricName": "",
    "Namespace": "",
    "Statistic": "Minimum",
    "ExtendedStatistic": "",
    "Dimensions": [
        {
            "Name": "",
            "Value": ""
        }
    ],
    "Period": 0,
    "Unit": "Terabytes/Second",
    "EvaluationPeriods": 0,
    "DatapointsToAlarm": 0,
    "Threshold": null,
    "ComparisonOperator": "LessThanOrEqualToThreshold",
    "TreatMissingData": "",
    "EvaluateLowSampleCountPercentile": "",
    "Metrics": [
        {
            "Id": "",
            "MetricStat": {
                "Metric": {
                    "Namespace": "",
                    "MetricName": "",
                    "Dimensions": [
                        {
                            "Name": "",
                            "Value": ""
                        }
                    ]
                },
                "Period": 0,
                "Stat": "",
                "Unit": "Seconds"
            },
            "Expression": "",
            "Label": "",
            "ReturnData": true,
            "Period": 0
        }
    ],
    "Tags": [
        {
            "Key": "",
            "Value": ""
        }
    ],
    "ThresholdMetricId": ""
}
EOF

# vim: set ts=4 sw=4 et ai:
