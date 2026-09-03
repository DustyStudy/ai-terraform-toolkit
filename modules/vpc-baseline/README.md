# vpc-baseline

A VPC with public and private subnets across the given availability zones, NAT gateway(s)
(single shared or one per AZ), VPC flow logs to CloudWatch, and the default security group
stripped of its default allow-all rules (per AWS best practice — the default SG should never
be used directly).

## Usage

```hcl
module "vpc" {
  source = "../../modules/vpc-baseline"

  name_prefix = "acme-prod"
  vpc_cidr    = "10.0.0.0/16"

  public_subnet_cidrs = {
    "us-east-1a" = "10.0.0.0/24"
    "us-east-1b" = "10.0.1.0/24"
  }

  private_subnet_cidrs = {
    "us-east-1a" = "10.0.10.0/24"
    "us-east-1b" = "10.0.11.0/24"
  }

  single_nat_gateway = true  # set false for one NAT per AZ (higher availability, higher cost)

  tags = {
    Environment = "prod"
    Owner       = "platform-team"
    ManagedBy   = "terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `name_prefix` | Prefix for all resource names | `string` | n/a (required) |
| `vpc_cidr` | CIDR block for the VPC | `string` | n/a (required) |
| `public_subnet_cidrs` | Map of AZ => CIDR for public subnets | `map(string)` | n/a (required) |
| `private_subnet_cidrs` | Map of AZ => CIDR for private subnets | `map(string)` | n/a (required) |
| `single_nat_gateway` | One shared NAT gateway vs. one per AZ | `bool` | `true` |
| `flow_log_retention_days` | CloudWatch Logs retention for flow logs | `number` | `365` |
| `tags` | Tags applied to all resources | `map(string)` | `{}` |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | VPC ID |
| `public_subnet_ids` | Map of AZ => public subnet ID |
| `private_subnet_ids` | Map of AZ => private subnet ID |
| `nat_gateway_ids` | Map of key => NAT gateway ID |

## Notes

- Flow logs are encrypted with a dedicated customer-managed KMS key created by this module
  (`aws_kms_key.flow_logs`), not CloudWatch's default encryption.
- `single_nat_gateway = true` is cheaper but means all private subnets lose internet egress if
  that one NAT gateway's AZ has an outage. Use `false` for production workloads that need
  multi-AZ resilience.
- This module intentionally does not create any security groups beyond stripping the default —
  create workload-specific security groups alongside whatever you deploy into these subnets.
