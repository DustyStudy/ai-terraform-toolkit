output "cloudtrail_arn" {
  description = "ARN of the CloudTrail trail created by this module."
  value       = aws_cloudtrail.this.arn
}

output "cloudtrail_bucket_name" {
  description = "Name of the S3 bucket storing CloudTrail logs."
  value       = aws_s3_bucket.cloudtrail.id
}

output "config_bucket_name" {
  description = "Name of the S3 bucket storing AWS Config logs, if enabled."
  value       = var.enable_config ? aws_s3_bucket.config[0].id : null
}

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector, if enabled."
  value       = var.enable_guardduty ? aws_guardduty_detector.this[0].id : null
}
