# Native Terraform tests (terraform >= 1.7's built-in test framework). Run with:
#   terraform test
# from inside modules/s3-secure-bucket/. Uses mock_provider, so no AWS credentials or network
# access are needed — everything here runs entirely offline. CI runs this on every PR (see
# .github/workflows/ci.yml's terraform-test job).
#
# What these tests do and don't cover: they check that variables produce the resource structure
# and wiring you'd expect (counts, conditionals, attribute pass-through) — they do NOT validate
# the actual content of IAM policy JSON, since aws_iam_policy_document data sources are purely
# local computation that a full provider mock fakes out rather than evaluates for real. Policy
# *content* correctness is what Checkov/Trivy/Terrascan are for; these tests are about the
# module's Terraform logic being correct.

mock_provider "aws" {
  mock_resource "aws_s3_bucket" {
    defaults = {
      id = "mock-bucket-id"

      arn = "arn:aws:s3:::mock-bucket-id"
    }
  }
  mock_resource "aws_kms_key" {
    defaults = {
      id = "mock-kms-key-id"

      arn = "arn:aws:kms:us-east-1:123456789012:key/mock-kms-key-id"
    }
  }

  # See account-baseline's tests/main.tftest.hcl for why this override is necessary: without it,
  # aws_iam_policy_document's mocked .json output isn't valid JSON, which fails provider-side
  # validation on the KMS key policy / bucket policy arguments before any real API call happens.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

run "defaults_create_a_secure_bucket" {
  command = apply

  variables {
    bucket_name = "test-bucket"
  }

  assert {
    condition = aws_s3_bucket.this.bucket == "test-bucket"

    error_message = "Bucket name should pass through from the bucket_name variable unchanged."
  }

  assert {
    condition = aws_s3_bucket_public_access_block.this.block_public_acls == true && aws_s3_bucket_public_access_block.this.block_public_policy == true && aws_s3_bucket_public_access_block.this.ignore_public_acls == true && aws_s3_bucket_public_access_block.this.restrict_public_buckets == true

    error_message = "All four public-access-block settings must always be true — none of this should be configurable to a less-safe value."
  }

  assert {
    condition = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"

    error_message = "Versioning should default to Enabled."
  }

  assert {
    condition = length(aws_kms_key.this) == 1

    error_message = "A dedicated KMS key should be created when kms_key_arn is not supplied."
  }

  assert {
    condition = aws_s3_bucket_server_side_encryption_configuration.this.rule[0].apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms"

    error_message = "Encryption must default to SSE-KMS, not SSE-S3."
  }

  assert {
    condition = aws_s3_bucket_notification.this.eventbridge == true

    error_message = "EventBridge notifications should always be enabled."
  }

  assert {
    condition = length(aws_s3_bucket_lifecycle_configuration.this.rule) == 1

    error_message = "Exactly one lifecycle rule (the mandatory abort-incomplete-multipart-upload rule) should exist when no lifecycle_rules are supplied."
  }

  assert {
    condition = aws_s3_bucket_lifecycle_configuration.this.rule[0].abort_incomplete_multipart_upload[0].days_after_initiation == 7

    error_message = "The mandatory abort-incomplete-multipart-upload rule should fire after 7 days."
  }

  assert {
    condition = length(aws_s3_bucket_logging.this) == 0

    error_message = "No access-logging resource should be created when access_log_bucket is not supplied."
  }
}

run "external_kms_key_is_used_instead_of_creating_one" {
  command = apply

  variables {
    bucket_name = "test-bucket"

    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/external-key"
  }

  assert {
    condition = length(aws_kms_key.this) == 0

    error_message = "No KMS key should be created when kms_key_arn is explicitly supplied."
  }

  assert {
    condition = aws_s3_bucket_server_side_encryption_configuration.this.rule[0].apply_server_side_encryption_by_default[0].kms_master_key_id == "arn:aws:kms:us-east-1:123456789012:key/external-key"

    error_message = "The bucket's SSE config should use the externally-supplied key, not a module-created one."
  }

  assert {
    condition = output.kms_key_arn == "arn:aws:kms:us-east-1:123456789012:key/external-key"

    error_message = "The kms_key_arn output should echo the externally-supplied key when one is given."
  }
}

run "versioning_can_be_suspended" {
  command = apply

  variables {
    bucket_name = "test-bucket"

    enable_versioning = false
  }

  assert {
    condition = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Suspended"

    error_message = "enable_versioning = false should result in Suspended status, not Disabled or Enabled."
  }
}

run "access_log_bucket_creates_logging_config" {
  command = apply

  variables {
    bucket_name = "test-bucket"

    access_log_bucket = "my-log-bucket"
  }

  assert {
    condition = length(aws_s3_bucket_logging.this) == 1

    error_message = "Supplying access_log_bucket should create exactly one logging resource."
  }

  assert {
    condition = aws_s3_bucket_logging.this[0].target_bucket == "my-log-bucket"

    error_message = "Access logs should be targeted at the supplied bucket."
  }

  assert {
    condition = aws_s3_bucket_logging.this[0].target_prefix == "test-bucket/"

    error_message = "The logging prefix should be the bucket name plus a trailing slash, to keep multiple buckets' logs distinguishable in a shared log bucket."
  }
}

run "user_lifecycle_rules_are_added_alongside_the_mandatory_one" {
  command = apply

  variables {
    bucket_name = "test-bucket"

    lifecycle_rules = [
      {
        id = "expire-old-objects"

        expiration_days = 90
      }
    ]
  }

  assert {
    condition = length(aws_s3_bucket_lifecycle_configuration.this.rule) == 2

    error_message = "A user-supplied lifecycle rule should be added alongside the mandatory abort-incomplete-multipart-upload rule, not replace it."
  }
}
