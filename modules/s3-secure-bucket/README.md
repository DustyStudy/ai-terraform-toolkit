# s3-secure-bucket

An S3 bucket with security defaults baked in: public access fully blocked, versioning on,
KMS encryption (bring your own key or let the module create one), a bucket policy denying
non-TLS requests, optional access logging to a separate bucket, and optional lifecycle rules.

## Usage

```hcl
module "reports_bucket" {
  source = "../../modules/s3-secure-bucket"

  bucket_name       = "acme-prod-reports-a1b2c3"
  access_log_bucket = "acme-prod-access-logs"

  lifecycle_rules = [
    {
      id = "expire-old-reports"
      transitions = [
        { days = 90, storage_class = "STANDARD_IA" }
      ]
      expiration_days = 365
    }
  ]

  tags = {
    Environment = "prod"
    Owner       = "data-team"
    ManagedBy   = "terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `bucket_name` | Globally unique bucket name | `string` | n/a (required) |
| `enable_versioning` | Enable object versioning | `bool` | `true` |
| `kms_key_arn` | Existing KMS key ARN; if null, one is created | `string` | `null` |
| `access_log_bucket` | Bucket to send access logs to | `string` | `null` |
| `lifecycle_rules` | List of lifecycle rule objects | `any` | `[]` |
| `tags` | Tags applied to the bucket | `map(string)` | `{}` |

## Outputs

| Name | Description |
|---|---|
| `bucket_id` | Bucket name |
| `bucket_arn` | Bucket ARN |
| `kms_key_arn` | KMS key ARN used for encryption |

## Notes

- Bucket names must be globally unique across all of AWS — include an account ID or random
  suffix if you're not sure the name is free.
- If you're using this as the `access_log_bucket` target for another instance of this module,
  create the logging bucket first without an `access_log_bucket` of its own (avoid a logging
  cycle).
