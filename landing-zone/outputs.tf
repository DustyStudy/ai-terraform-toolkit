output "cloudtrail_arn" {
  description = "ARN of the account's CloudTrail trail."
  value       = module.account_baseline.cloudtrail_arn
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID for this account."
  value       = module.account_baseline.guardduty_detector_id
}

output "vpc_id" {
  description = "VPC ID, if a VPC was created."
  value       = var.create_vpc ? module.vpc[0].vpc_id : null
}
