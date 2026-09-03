# account-baseline

Applies the standard security baseline to a single AWS account: multi-region CloudTrail (KMS
encrypted, log-file validation on), AWS Config, GuardDuty, and SCP attachment for org member
accounts.

This module does **not** author SCP policy content — it only attaches existing SCPs (created in
your org's management account) to the target account by policy ID.

## Usage

```hcl
module "account_baseline" {
  source = "../../modules/account-baseline"

  name_prefix       = "acme"
  account_id        = "123456789012"
  enable_config     = true
  enable_guardduty  = true

  attach_scp_ids = {
    deny_root_actions = "p-abc12345"
    require_region    = "p-def67890"
  }

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
| `account_id` | Target account ID for SCP attachment | `string` | `""` |
| `enable_config` | Enable AWS Config | `bool` | `true` |
| `enable_guardduty` | Enable GuardDuty | `bool` | `true` |
| `enable_eks_protection` | Enable GuardDuty EKS audit log protection | `bool` | `false` |
| `attach_scp_ids` | Map of SCP policy IDs to attach | `map(string)` | `{}` |
| `tags` | Tags applied to all resources | `map(string)` | `{}` |

## Outputs

| Name | Description |
|---|---|
| `cloudtrail_arn` | ARN of the CloudTrail trail |
| `cloudtrail_bucket_name` | S3 bucket storing CloudTrail logs |
| `config_bucket_name` | S3 bucket storing Config logs (if enabled) |
| `guardduty_detector_id` | GuardDuty detector ID (if enabled) |

## Notes

- Requires the caller to have organization-level permissions if `attach_scp_ids` is non-empty.
- CloudTrail and Config each get their own dedicated, private, encrypted S3 bucket — this module
  does not assume a pre-existing log-archive bucket, so it works standalone in a single account
  or as part of a larger landing zone.
