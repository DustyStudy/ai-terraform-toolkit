variable "aws_region" {
  description = "AWS region to create the state bucket and lock table in."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix used for naming the state bucket and lock table (e.g. an org or team identifier)."
  type        = string
}

variable "tags" {
  description = "Tags applied to the state bucket and lock table."
  type        = map(string)
  default     = {}
}
