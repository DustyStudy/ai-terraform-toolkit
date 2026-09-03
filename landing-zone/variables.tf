variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix used for naming all resources (e.g. an org or team identifier plus environment)."
  type        = string
}

variable "account_id" {
  description = "AWS account ID being seeded/configured."
  type        = string
}

variable "enable_config" {
  description = "Whether to enable AWS Config."
  type        = bool
  default     = true
}

variable "enable_guardduty" {
  description = "Whether to enable GuardDuty."
  type        = bool
  default     = true
}

variable "attach_scp_ids" {
  description = "Map of SCP policy IDs (already created in the org management account) to attach."
  type        = map(string)
  default     = {}
}

variable "create_vpc" {
  description = "Whether to create a baseline VPC in this account."
  type        = bool
  default     = false
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC, if create_vpc is true."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Map of AZ => CIDR for public subnets, if create_vpc is true."
  type        = map(string)
  default     = {}
}

variable "private_subnet_cidrs" {
  description = "Map of AZ => CIDR for private subnets, if create_vpc is true."
  type        = map(string)
  default     = {}
}

variable "single_nat_gateway" {
  description = "One shared NAT gateway vs. one per AZ, if create_vpc is true."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
