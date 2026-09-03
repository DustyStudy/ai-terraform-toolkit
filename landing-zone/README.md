# landing-zone

Root Terraform config that seeds/configures a single AWS account: applies the account security
baseline (`modules/account-baseline`) and, optionally, a baseline VPC (`modules/vpc-baseline`).

Run this once per new account you bring into your org, authenticated against that account.

## Prerequisites

1. **Remote state backend.** Create an S3 bucket (versioned, encrypted) and a DynamoDB table
   (partition key `LockID`, string type) for state locking, before first use:

   ```bash
   aws s3api create-bucket --bucket your-org-terraform-state --region us-east-1
   aws s3api put-bucket-versioning --bucket your-org-terraform-state \
     --versioning-configuration Status=Enabled
   aws dynamodb create-table --table-name your-org-terraform-locks \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST
   ```

   Then fill in the `backend "s3"` block in `main.tf` (or pass equivalent `-backend-config`
   flags/files per environment).

2. **OIDC federation** between your CI system (e.g. GitHub Actions) and the target AWS account,
   so `terraform plan`/`apply` runs without long-lived access keys. This is out of scope for this
   module — set up an IAM OIDC identity provider and a role with a trust policy scoped to your
   CI provider before running this.

3. **SCPs already created** in your org's management account, if you're passing
   `attach_scp_ids` — this module attaches by policy ID, it doesn't author SCP content.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with real values
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

In normal use, `apply` should run via CI after a reviewed PR — see the repo root README and
`.github/workflows/ci.yml`. Local apply is for bootstrapping/testing only.

## Variables

See `variables.tf` for the full list. Key ones:

| Name | Description |
|---|---|
| `account_id` | The AWS account being seeded |
| `attach_scp_ids` | SCP policy IDs to attach to this account |
| `create_vpc` | Whether to also create a baseline VPC |

## Outputs

| Name | Description |
|---|---|
| `cloudtrail_arn` | ARN of the account's CloudTrail trail |
| `guardduty_detector_id` | GuardDuty detector ID |
| `vpc_id` | VPC ID, if created |
