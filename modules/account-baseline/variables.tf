variable "name_prefix" {
  description = "Prefix used for naming all resources created by this module (e.g. an org or team identifier)."
  type        = string
}

variable "account_id" {
  description = "AWS account ID this baseline is being applied to. Used only for SCP attachment target_id."
  type        = string
  default     = ""
}

variable "enable_cloudtrail_cloudwatch_logs" {
  description = "Whether to deliver CloudTrail logs to CloudWatch Logs in addition to S3, for near-real-time log review/alerting (supports FedRAMP AU-6)."
  type        = bool
  default     = true
}

variable "cloudtrail_log_retention_days" {
  description = "CloudWatch Logs retention period for the CloudTrail log group, if enabled. FedRAMP Moderate generally expects 90 days hot + 1 year total retention (cold storage can live in the S3 bucket instead)."
  type        = number
  default     = 90
}

variable "enable_config" {
  description = "Whether to enable AWS Config in this account."
  type        = bool
  default     = true
}

variable "enable_guardduty" {
  description = "Whether to enable GuardDuty in this account."
  type        = bool
  default     = true
}

variable "enable_eks_protection" {
  description = "Whether to enable GuardDuty EKS audit log protection. Set to false if the account has no EKS clusters."
  type        = bool
  default     = false
}

variable "attach_scp_ids" {
  description = "Map of SCP policy IDs (already created in the org management account) to attach to this account. Key is arbitrary/descriptive, value is the policy ID."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
  default     = {}
}
