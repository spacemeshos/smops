### Alarms: Dangling volumes
resource "aws_cloudwatch_metric_alarm" "volumes" {
  count = length(var.aws_region_list)

  actions_enabled           = true
  alarm_actions             = [ "arn:aws:sns:us-east-1:534354616613:spacemesh-testnet-alarm", ]
  alarm_description         = "There are dangling volumes in ${var.aws_region_list[count.index]}"
  alarm_name                = "Dangling volumes in ${var.aws_region_list[count.index]}"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  datapoints_to_alarm       = 1
  dimensions                = {}
  evaluation_periods        = 1
  insufficient_data_actions = []
  metric_name               = "miner-vol-available"
  namespace                 = "spacemesh/${var.aws_region_list[count.index]}"
  ok_actions                = []
  period                    = 900
  statistic                 = "Minimum"
  tags                      = {}
  threshold                 = 1
  treat_missing_data        = "notBreaching"
}

### Alarms: No data from scraper
resource "aws_cloudwatch_metric_alarm" "data" {
  count = length(var.aws_region_list)

  actions_enabled           = true
  alarm_actions             = [ "arn:aws:sns:us-east-1:534354616613:spacemesh-testnet-alarm", ]
  alarm_name                = "No data from ${var.aws_region_list[count.index]} miner"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = 1
  metric_name               = "miner-master-nodes"
  namespace                 = "spacemesh/${var.aws_region_list[count.index]}"
  period                    = 3600
  statistic                 = "SampleCount"
  threshold                 = 10
  treat_missing_data        = "missing"
}

### Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = var.project_name
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 0
        y      = 0

        properties = {
          title   = "nodes/region"
          view    = "timeSeries"
          period  = 300
          stacked = true
          region  = var.mgmt_region
          metrics = concat(
            [for region in var.aws_region_list: ["${var.project_name}/${region}", "miner-miner-nodes"]],
            [for region in var.aws_region_list: ["${var.project_name}/${region}", "initfactory-initfactory-nodes"]],
          )
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 8
        y      = 0

        properties = {
          title   = "used volumes/region"
          view    = "timeSeries"
          period  = 300
          stacked = true
          region  = var.mgmt_region
          metrics = concat(
            [for region in var.aws_region_list: ["${var.project_name}/${region}", "miner-vol-attached"]],
          )
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 16
        y      = 0

        properties = {
          title   = "dangling volumes/region"
          view    = "timeSeries"
          period  = 300
          stacked = true
          region  = var.mgmt_region
          metrics = concat(
            [for region in var.aws_region_list: ["${var.project_name}/${region}", "miner-vol-available"]],
          )
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 0
        y      = 6

        properties = {
          title   = "initfactory running/region"
          view    = "timeSeries"
          period  = 300
          stacked = true
          region  = var.mgmt_region
          metrics = concat(
            [for region in var.aws_region_list: ["${var.project_name}/${region}", "initfactory-initfactory-jobs-running"]],
          )
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 8
        y      = 6

        properties = {
          title   = "initfactory success/region"
          view    = "timeSeries"
          period  = 300
          stacked = true
          region  = var.mgmt_region
          metrics = concat(
            [for region in var.aws_region_list: ["${var.project_name}/${region}", "initfactory-initfactory-jobs-success"]],
          )
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 16
        y      = 6

        properties = {
          title   = "initfactory failed/region"
          view    = "timeSeries"
          period  = 300
          stacked = true
          region  = var.mgmt_region
          metrics = concat(
            [for region in var.aws_region_list: ["${var.project_name}/${region}", "initfactory-initfactory-jobs-failed"]],
          )
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 0
        y      = 12

        properties = {
          title   = "miners pending/region"
          view    = "timeSeries"
          period  = 300
          stacked = true
          region  = var.mgmt_region
          metrics = concat(
            [for region in var.aws_region_list: ["${var.project_name}/${region}", "miner-pods-pending"]],
          )
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 8
        y      = 12

        properties = {
          title   = "miners running/region"
          view    = "timeSeries"
          period  = 300
          stacked = true
          region  = var.mgmt_region
          metrics = concat(
            [for region in var.aws_region_list: ["${var.project_name}/${region}", "miner-pods-ok"]],
          )
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 16
        y      = 12

        properties = {
          title   = "miners error/region"
          view    = "timeSeries"
          period  = 300
          stacked = true
          region  = var.mgmt_region
          metrics = concat(
            [for region in var.aws_region_list: ["${var.project_name}/${region}", "miner-pods-error"]],
          )
        }
      },
    ]
  })
}

# vim:filetype=terraform ts=2 sw=2 et:
