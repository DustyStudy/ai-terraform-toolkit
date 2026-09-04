# Native Terraform tests. Run with `terraform test` from modules/account-baseline/. Fully
# offline via mock_provider — see modules/s3-secure-bucket/tests/main.tftest.hcl for the fuller
# explanation of scope/limits (IAM policy JSON *content* isn't validated here; Checkov/Trivy/
# Terrascan own that).
#
# Most assertions below are self-referential (e.g. "does the CloudTrail resource's kms_key_id
# equal the logs KMS key's arn") rather than comparing against a hardcoded expected string —
# Terraform's mock system resolves a given resource's computed attribute to the same fake value
# every time it's read within one test run, so these equality checks are meaningful without
# needing explicit mock_resource default overrides.

mock_provider "aws" {
  # aws_iam_policy_document is pure local computation (no real AWS API call), but a full
  # provider mock fakes its .json output anyway — as a non-JSON placeholder string. That breaks
  # every resource argument that requires syntactically valid JSON (assume_role_policy, policy),
  # since the provider validates JSON syntax client-side before any real API call happens. This
  # override gives every aws_iam_policy_document instance a real, minimal, valid JSON string
  # instead, so those arguments pass validation. It is NOT the real computed policy content —
  # see the file header note on what these tests do and don't validate.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

run "guardduty_enabled_by_default" {
  command = apply

  variables {
    name_prefix = "test"

    account_id = "111111111111"
  }

  assert {
    condition = length(aws_guardduty_detector.this) == 1

    error_message = "GuardDuty should be enabled by default (enable_guardduty defaults to true)."
  }

  assert {
    condition = output.guardduty_detector_id != null

    error_message = "guardduty_detector_id output should be non-null when GuardDuty is enabled."
  }

  assert {
    condition = aws_guardduty_detector.this[0].datasources[0].kubernetes[0].audit_logs[0].enable == false

    error_message = "EKS audit log protection should default to disabled (enable_eks_protection defaults to false)."
  }
}

run "guardduty_can_be_disabled" {
  command = apply

  variables {
    name_prefix = "test"

    account_id = "111111111111"

    enable_guardduty = false
  }

  assert {
    condition = length(aws_guardduty_detector.this) == 0

    error_message = "No GuardDuty detector should be created when enable_guardduty is false."
  }

  assert {
    condition = output.guardduty_detector_id == null

    error_message = "guardduty_detector_id output should be null when GuardDuty is disabled."
  }
}

run "eks_protection_can_be_enabled" {
  command = apply

  variables {
    name_prefix = "test"

    account_id = "111111111111"

    enable_eks_protection = true
  }

  assert {
    condition = aws_guardduty_detector.this[0].datasources[0].kubernetes[0].audit_logs[0].enable == true

    error_message = "enable_eks_protection = true should turn on GuardDuty's Kubernetes audit log protection."
  }
}

run "no_scp_attachments_by_default" {
  command = apply

  variables {
    name_prefix = "test"

    account_id = "111111111111"
  }

  assert {
    condition = length(aws_organizations_policy_attachment.scp) == 0

    error_message = "No SCP attachments should be created when attach_scp_ids is empty (the default)."
  }
}

run "one_scp_attachment_per_supplied_policy_id" {
  command = apply

  variables {
    name_prefix = "test"

    account_id = "111111111111"

    attach_scp_ids = {
      deny_root_actions = "p-aaaaaaaa"

      require_region = "p-bbbbbbbb"
    }
  }

  assert {
    condition = length(aws_organizations_policy_attachment.scp) == 2

    error_message = "Each entry in attach_scp_ids should produce exactly one policy attachment."
  }

  assert {
    condition = alltrue([for a in aws_organizations_policy_attachment.scp : a.target_id == "111111111111"])

    error_message = "Every SCP attachment should target the account_id variable, not some other account."
  }
}

run "cloudtrail_is_wired_to_the_shared_logs_kms_key_and_its_own_resources" {
  command = apply

  variables {
    name_prefix = "test"

    account_id = "111111111111"
  }

  assert {
    condition = aws_cloudtrail.this.kms_key_id == aws_kms_key.logs.arn

    error_message = "CloudTrail must be encrypted with this module's shared logs KMS key."
  }

  assert {
    condition = aws_cloudtrail.this.cloud_watch_logs_role_arn == aws_iam_role.cloudtrail_cloudwatch.arn

    error_message = "CloudTrail's CloudWatch Logs delivery role must be the dedicated role this module creates for it, not left unset."
  }

  assert {
    condition = aws_cloudtrail.this.sns_topic_name == aws_sns_topic.cloudtrail.arn

    error_message = "CloudTrail must publish to the SNS topic this module creates for it."
  }

  assert {
    condition = aws_cloudwatch_log_group.cloudtrail.retention_in_days == 365

    error_message = "CloudTrail's CloudWatch Logs retention should default to 365 days (FedRAMP Moderate 1-year minimum)."
  }
}

run "config_bucket_uses_kms_not_aes256" {
  command = apply

  variables {
    name_prefix = "test"

    account_id = "111111111111"
  }

  assert {
    condition = aws_s3_bucket_server_side_encryption_configuration.config.rule[0].apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms"

    error_message = "The Config delivery bucket must use SSE-KMS, not the AWS-managed SSE-S3 default."
  }

  assert {
    condition = aws_s3_bucket_server_side_encryption_configuration.config.rule[0].apply_server_side_encryption_by_default[0].kms_master_key_id == aws_kms_key.logs.arn

    error_message = "The Config delivery bucket must use this module's shared logs KMS key."
  }
}

run "access_logs_bucket_uses_aes256_not_kms" {
  command = apply

  variables {
    name_prefix = "test"

    account_id = "111111111111"
  }

  assert {
    condition = aws_s3_bucket_server_side_encryption_configuration.access_logs.rule[0].apply_server_side_encryption_by_default[0].sse_algorithm == "AES256"

    error_message = "The access-logs bucket must use SSE-S3 (AES256) — AWS does not support SSE-KMS for S3 server-access-log target buckets."
  }
}

run "cloudtrail_and_config_buckets_both_log_to_the_shared_access_logs_bucket" {
  command = apply

  variables {
    name_prefix = "test"

    account_id = "111111111111"
  }

  assert {
    condition = aws_s3_bucket_logging.cloudtrail.target_bucket == aws_s3_bucket.access_logs.id

    error_message = "The CloudTrail bucket's access logs must be delivered to this module's dedicated access-logs bucket."
  }

  assert {
    condition = aws_s3_bucket_logging.config.target_bucket == aws_s3_bucket.access_logs.id

    error_message = "The Config bucket's access logs must be delivered to this module's dedicated access-logs bucket."
  }
}

run "outputs_reference_the_correct_resources" {
  command = apply

  variables {
    name_prefix = "test"

    account_id = "111111111111"
  }

  assert {
    condition = output.cloudtrail_arn == aws_cloudtrail.this.arn

    error_message = "cloudtrail_arn output should be the actual CloudTrail trail's ARN."
  }

  assert {
    condition = output.config_bucket_name == aws_s3_bucket.config.id

    error_message = "config_bucket_name output should be the actual Config bucket's name."
  }

  assert {
    condition = output.access_logs_bucket_name == aws_s3_bucket.access_logs.id

    error_message = "access_logs_bucket_name output should be the actual access-logs bucket's name."
  }

  assert {
    condition = output.cloudtrail_sns_topic_arn == aws_sns_topic.cloudtrail.arn

    error_message = "cloudtrail_sns_topic_arn output should be the actual SNS topic's ARN."
  }
}
