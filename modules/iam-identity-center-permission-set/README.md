# iam-identity-center-permission-set

Creates a standardized IAM Identity Center (AWS SSO) permission set — with AWS managed policies,
an optional inline policy, and an optional permissions boundary — and assigns it to a group or
user across one or more target accounts.

Requires IAM Identity Center to already be enabled for the organization, and requires knowing the
principal (group/user) ID from Identity Center ahead of time.

## Usage

```hcl
module "security_readonly" {
  source = "../../modules/iam-identity-center-permission-set"

  permission_set_name = "SecurityReadOnly"
  description          = "Read-only access for the security team across all accounts"
  session_duration      = "PT8H"

  aws_managed_policy_arns = [
    "arn:aws:iam::aws:policy/SecurityAudit",
    "arn:aws:iam::aws:policy/ReadOnlyAccess",
  ]

  target_account_ids = ["111111111111", "222222222222"]
  principal_id       = "g-abc123456"
  principal_type     = "GROUP"

  tags = {
    Environment = "shared"
    Owner       = "security-team"
    ManagedBy   = "terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `permission_set_name` | Name of the permission set | `string` | n/a (required) |
| `description` | Description | `string` | `""` |
| `session_duration` | ISO-8601 session duration | `string` | `"PT4H"` |
| `aws_managed_policy_arns` | AWS managed policies to attach | `list(string)` | `[]` |
| `inline_policy_json` | Inline policy JSON | `string` | `null` |
| `permissions_boundary_policy_arn` | Permissions boundary policy ARN | `string` | `null` |
| `target_account_ids` | Accounts to assign this permission set to | `list(string)` | n/a (required) |
| `principal_id` | Identity Center group/user ID | `string` | n/a (required) |
| `principal_type` | `GROUP` or `USER` | `string` | `"GROUP"` |
| `tags` | Tags applied to the permission set | `map(string)` | `{}` |

## Outputs

| Name | Description |
|---|---|
| `permission_set_arn` | ARN of the created permission set |
| `permission_set_name` | Name of the created permission set |

## Notes

- To find a group's `principal_id`, use `aws identitystore list-groups` against your Identity
  Store ID, or look it up in the IAM Identity Center console under Groups.
- Prefer least-privilege AWS managed policies or a tightly scoped inline policy over broad
  policies like `AdministratorAccess`, even for "temporary" permission sets.
