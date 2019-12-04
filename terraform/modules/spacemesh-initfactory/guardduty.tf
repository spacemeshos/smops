# FIXME: GuardDuty publishing to S3 is not supported by Terraform AWS Provider

### GuardDuty Detector
resource "aws_guardduty_detector" "guardduty" {
  enable = true

  finding_publishing_frequency = "SIX_HOURS"
}


# vim:filetype=terraform ts=2 sw=2 et:
