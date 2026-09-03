variable "name_prefix" {
  description = "Prefix used for naming all resources created by this module (e.g. an org or team identifier)."
  type        = string
}

variable "account_id" {
  description = "AWS account ID this baseline is being applied to. Used only for SCP attachment target_id."
  type        = string
  default     = ""
}

variable "cloudtrail_log_retention_days" {
  description = "CloudWatch Logs retention period for the CloudTrail log group. FedRAMP Moderate expects at least 1 year of retention; cold/long-term storage also lives indefinitely in the CloudTrail S3 bucket."
  type        = number
  default     = 365
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
