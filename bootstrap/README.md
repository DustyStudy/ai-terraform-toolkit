# bootstrap

Creates the S3 bucket and DynamoDB table that every other root config in this repo
(`landing-zone`, and any root config you add) uses as its remote state backend. Run this once
per AWS account (or once per org, if you're centralizing state for multiple accounts into a
single state-hosting account).

## Why this is a separate root config

Terraform state for a config lives in the backend that config points to. But the backend itself
— the S3 bucket and DynamoDB table — has to exist *before* anything can use it as a backend.
This config solves that chicken-and-egg problem by deliberately using **local** state for itself,
so it can create the bucket/table without depending on them.

## Usage

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with real values
terraform init
terraform apply -var-file=terraform.tfvars
```

This creates a local `terraform.tfstate` file in this directory. **Don't lose it** — treat it
like you would any other Terraform state — and see the migration step below for getting it out
of local storage entirely.

## After applying: point other configs at the new backend

Take the `state_bucket_name` and `lock_table_name` outputs and fill in the `backend "s3"` block
in `landing-zone/main.tf` (or any other root config):

```hcl
backend "s3" {
  bucket         = "<state_bucket_name output>"
  key            = "landing-zone/<account-id>/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "<lock_table_name output>"
  encrypt        = true
}
```

## Optional: migrate this config's own state into the bucket it created

Once the bucket exists, you can move `bootstrap`'s own state out of local storage and into the
bucket, so it's versioned/backed-up like everything else:

1. Add a `backend "s3"` block to `bootstrap/main.tf` pointing at the bucket/table this config
   just created (a `bootstrap/<something>/terraform.tfstate` key, distinct from other configs').
2. Run `terraform init -migrate-state` and confirm when prompted. Terraform copies the local
   state into the new backend.
3. Delete the local `terraform.tfstate`/`terraform.tfstate.backup` files once you've confirmed
   the migration succeeded (`terraform state list` against the new backend shows the same
   resources).

This step is optional — plenty of teams just keep `bootstrap`'s state local and treat this config
as a rarely-touched, mostly-one-time thing. If you do migrate it, remember `bootstrap` now has a
dependency on the backend it manages, which is a little unusual — that's the tradeoff.

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `aws_region` | AWS region to create the state bucket and lock table in | `string` | `"us-east-1"` |
| `name_prefix` | Prefix used for naming the state bucket and lock table | `string` | n/a (required) |
| `tags` | Tags applied to the state bucket and lock table | `map(string)` | `{}` |

## Outputs

| Name | Description |
|---|---|
| `state_bucket_name` | S3 bucket to use as `bucket` in other configs' backend blocks |
| `state_bucket_arn` | ARN of the state bucket |
| `lock_table_name` | DynamoDB table to use as `dynamodb_table` in other configs' backend blocks |
| `lock_table_arn` | ARN of the DynamoDB lock table |
<!-- END_TF_DOCS -->
