output "cloudtrail_arn" {
  description = "ARN of the CloudTrail trail created by this module."
  value       = aws_cloudtrail.this.arn
}

output "cloudtrail_bucket_name" {
  description = "Name of the S3 bucket storing CloudTrail logs."
  value       = aws_s3_bucket.cloudtrail.id
}

output "config_bucket_name" {
  description = "Name of the S3 bucket storing AWS Config logs."
  value       = aws_s3_bucket.config.id
}

output "access_logs_bucket_name" {
  description = "Name of the S3 bucket storing access logs for the other buckets in this module."
  value       = aws_s3_bucket.access_logs.id
}

output "cloudtrail_sns_topic_arn" {
  description = "ARN of the SNS topic CloudTrail publishes log-delivery notifications to."
  value       = aws_sns_topic.cloudtrail.arn
}

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector, if enabled."
  value       = var.enable_guardduty ? aws_guardduty_detector.this[0].id : null
}
