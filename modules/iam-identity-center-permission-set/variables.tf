variable "permission_set_name" {
  description = "Name of the permission set."
  type        = string
}

variable "description" {
  description = "Description of the permission set's purpose. AWS requires this to be 1-700 characters if set at all, so an empty string (the default) omits the argument entirely rather than sending an invalid empty description."
  type        = string
  default     = ""
}

variable "session_duration" {
  description = "Session duration in ISO-8601 format (e.g. PT4H for 4 hours, PT8H for 8 hours)."
  type        = string
  default     = "PT4H"
}

variable "aws_managed_policy_arns" {
  description = "List of AWS managed policy ARNs to attach to the permission set."
  type        = list(string)
  default     = []
}

variable "inline_policy_json" {
  description = "Inline IAM policy JSON to attach to the permission set. Null to skip."
  type        = string
  default     = null
}

variable "permissions_boundary_policy_arn" {
  description = "AWS managed policy ARN to use as a permissions boundary on this permission set. Null to skip."
  type        = string
  default     = null
}

variable "target_account_ids" {
  description = "List of AWS account IDs to assign this permission set to."
  type        = list(string)
}

variable "principal_id" {
  description = "The group or user ID (from Identity Center) to assign the permission set to."
  type        = string
}

variable "principal_type" {
  description = "Either GROUP or USER."
  type        = string
  default     = "GROUP"

  validation {
    condition     = contains(["GROUP", "USER"], var.principal_type)
    error_message = "principal_type must be either GROUP or USER."
  }
}

variable "tags" {
  description = "Tags applied to the permission set."
  type        = map(string)
  default     = {}
}
