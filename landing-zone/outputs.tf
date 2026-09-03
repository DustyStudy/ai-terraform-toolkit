output "cloudtrail_arn" {
  description = "ARN of the account's CloudTrail trail."
  value       = module.account_baseline.cloudtrail_arn
}

output "config_bucket_name" {
  description = "S3 bucket storing this account's AWS Config logs."
  value       = module.account_baseline.config_bucket_name
}

output "access_logs_bucket_name" {
  description = "S3 bucket storing access logs for the CloudTrail/Config buckets."
  value       = module.account_baseline.access_logs_bucket_name
}

output "cloudtrail_sns_topic_arn" {
  description = "ARN of the SNS topic CloudTrail publishes log-delivery notifications to."
  value       = module.account_baseline.cloudtrail_sns_topic_arn
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID for this account."
  value       = module.account_baseline.guardduty_detector_id
}

output "vpc_id" {
  description = "VPC ID, if a VPC was created."
  value       = var.create_vpc ? module.vpc[0].vpc_id : null
}
