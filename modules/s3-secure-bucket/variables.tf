variable "bucket_name" {
  description = "Globally unique S3 bucket name."
  type        = string
}

variable "enable_versioning" {
  description = "Whether to enable object versioning."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "Existing KMS key ARN to use for encryption. If null, a dedicated key is created for this bucket."
  type        = string
  default     = null
}

variable "access_log_bucket" {
  description = "Name of an existing bucket to send S3 access logs to. If null, access logging is not configured."
  type        = string
  default     = null
}

variable "lifecycle_rules" {
  description = <<-EOT
    List of lifecycle rule objects. Each object supports:
      id              (string, required)
      transitions     (list of { days = number, storage_class = string }, optional)
      expiration_days (number, optional)
  EOT
  type        = any
  default     = []
}

variable "tags" {
  description = "Tags applied to the bucket."
  type        = map(string)
  default     = {}
}
