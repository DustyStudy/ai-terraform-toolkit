Create a new S3 bucket using the `s3-secure-bucket` module — never write a raw `aws_s3_bucket`
resource for this.

Ask the user for whatever of the following you don't already know from context:
- Bucket purpose/name (remind them bucket names must be globally unique — suggest appending an
  account ID or short random suffix if they're not sure it's free)
- Which environment/root config this belongs in (e.g. an existing app's Terraform, or a new one)
- Whether they want a dedicated KMS key or to reuse an existing one (`kms_key_arn`)
- Whether they need access logging to another bucket, and if so, which bucket
- Whether they need lifecycle rules (e.g. transition to Infrequent Access, expiration) — ask what
  retention/transition behavior they want in plain English and translate it into the
  `lifecycle_rules` structure
- Required tags per `CLAUDE.md` conventions (`Environment`, `Owner`, `ManagedBy`, `CostCenter`) —
  ask for any you don't know, don't guess

Then:
1. Add a `module "..."` block calling `modules/s3-secure-bucket` in the appropriate root config.
2. Run `terraform fmt` and `terraform validate`.
3. Show the user the diff and a plain-English summary of what will be created.
4. Do not run `terraform apply`.
5. Suggest running the `tf-security-reviewer` subagent on the diff before opening a PR.
