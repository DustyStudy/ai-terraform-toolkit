variable "name_prefix" {
  description = "Prefix used for naming all resources created by this module."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Map of availability zone => CIDR block for public subnets, e.g. { \"us-east-1a\" = \"10.0.0.0/24\" }."
  type        = map(string)
}

variable "private_subnet_cidrs" {
  description = "Map of availability zone => CIDR block for private subnets, e.g. { \"us-east-1a\" = \"10.0.10.0/24\" }."
  type        = map(string)
}

variable "single_nat_gateway" {
  description = "If true, create one shared NAT gateway for all private subnets (cheaper). If false, one NAT gateway per AZ (more resilient)."
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "CloudWatch Logs retention period for VPC flow logs."
  type        = number
  default     = 90
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
  default     = {}
}
