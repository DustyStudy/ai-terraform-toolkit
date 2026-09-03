############################################
# account-baseline
#
# Applies the standard security baseline to a single AWS account:
# CloudTrail, AWS Config, GuardDuty, and SCP attachment (org member accounts only).
############################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

############################################
# CloudTrail
############################################

resource "aws_cloudtrail" "this" {
  name                          = "${var.name_prefix}-org-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.logs.arn
  sns_topic_name                = aws_sns_topic.cloudtrail.arn

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch.arn

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-org-trail"
  })

  depends_on = [aws_s3_bucket_policy.cloudtrail, aws_sns_topic_policy.cloudtrail]
}

resource "aws_sns_topic" "cloudtrail" {
  name              = "${var.name_prefix}-cloudtrail-notifications"
  kms_master_key_id = aws_kms_key.logs.id

  tags = var.tags
}

resource "aws_sns_topic_policy" "cloudtrail" {
  arn    = aws_sns_topic.cloudtrail.arn
  policy = data.aws_iam_policy_document.cloudtrail_sns.json
}

data "aws_iam_policy_document" "cloudtrail_sns" {
  statement {
    sid    = "AWSCloudTrailSNSPolicy"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.cloudtrail.arn]

    # Scoped to this account rather than a specific trail ARN to avoid a circular dependency
    # (the trail references this topic, so the topic policy can't also reference the trail).
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.name_prefix}-org-trail"
  retention_in_days = var.cloudtrail_log_retention_days
  kms_key_id        = aws_kms_key.logs.arn

  tags = var.tags
}

resource "aws_iam_role" "cloudtrail_cloudwatch" {
  name               = "${var.name_prefix}-cloudtrail-cwl-role"
  assume_role_policy = data.aws_iam_policy_document.cloudtrail_cloudwatch_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "cloudtrail_cloudwatch_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  name   = "${var.name_prefix}-cloudtrail-cwl-delivery"
  role   = aws_iam_role.cloudtrail_cloudwatch.id
  policy = data.aws_iam_policy_document.cloudtrail_cloudwatch_delivery.json
}

data "aws_iam_policy_document" "cloudtrail_cloudwatch_delivery" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    # trivy:ignore:AVD-AWS-0057 The ":*" suffix is the standard AWS pattern for a CloudWatch
    # log group ARN — it means "all log streams within this specific, named log group," not an
    # unconstrained wildcard. Stream names are assigned dynamically by CloudTrail and can't be
    # enumerated in advance, so this is as scoped as this permission can get.
    resources = ["${aws_cloudwatch_log_group.cloudtrail.arn}:*"]
  }
}

resource "aws_s3_bucket" "cloudtrail" {
  bucket = "${var.name_prefix}-cloudtrail-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cloudtrail-logs"
  })

  # checkov:skip=CKV_AWS_144: Cross-region replication needs a pre-provisioned destination
  # bucket + IAM role that are environment-specific; not a sane default for a reusable module.
  # Add aws_s3_bucket_replication_configuration in the calling root config if your org requires
  # cross-region DR for audit logs.
}

resource "aws_s3_bucket_logging" "cloudtrail" {
  bucket        = aws_s3_bucket.cloudtrail.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "cloudtrail-bucket/"
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_notification" "cloudtrail" {
  bucket      = aws_s3_bucket.cloudtrail.id
  eventbridge = true
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket                  = aws_s3_bucket.cloudtrail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.logs.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail_bucket.json
}

data "aws_iam_policy_document" "cloudtrail_bucket" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail.arn]
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_kms_key" "logs" {
  description             = "KMS key for ${var.name_prefix} audit log encryption (CloudTrail, Config, CloudWatch Logs)"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.logs_kms.json

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-logs-kms"
  })
}

data "aws_iam_policy_document" "logs_kms" {
  statement {
    sid    = "AllowRootAccountFullAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    # checkov:skip=CKV_AWS_109: This is AWS's own documented default KMS key policy statement
    # (see "Default key policy" in the KMS developer guide) — it grants the account's IAM
    # policies control over the key so it stays manageable/rotatable, not direct data access.
    # A KMS key with no such statement and no other administrative grant becomes unmanageable.
    # checkov:skip=CKV_AWS_111: same rationale — root access here is key administration
    # (rotate, schedule deletion, update policy), not unconstrained data-plane write access.
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudTrailEncrypt"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["kms:GenerateDataKey*", "kms:DescribeKey"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowConfigEncrypt"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    actions   = ["kms:GenerateDataKey*", "kms:DescribeKey", "kms:Decrypt"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudWatchLogsEncrypt"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }
    actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
    resources = ["*"]
  }
}

############################################
# Access-logs sink bucket
#
# Dedicated target for S3 server access logs from the other buckets in this module. AWS
# requires server-access-log target buckets to use SSE-S3 (not SSE-KMS), so this bucket is
# deliberately AES256-encrypted rather than reusing the KMS key used elsewhere.
############################################

resource "aws_s3_bucket" "access_logs" {
  bucket = "${var.name_prefix}-access-logs-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-access-logs"
  })

  # checkov:skip=CKV_AWS_18: this bucket IS the access-log destination for the other buckets in
  # this module; pointing it at itself (or a second sink) would just add an infinite logging loop.
  # checkov:skip=CKV_AWS_144: see cloudtrail bucket above — replication is environment-specific
  # and opt-in, not a sane default for a reusable module.
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket                  = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# trivy:ignore:AVD-AWS-0132 AWS does not support SSE-KMS for S3 server-access-log target
# buckets, only SSE-S3 — this is a hard AWS platform constraint, not a design choice. Same
# rationale as the CKV_AWS_145 skip below.
resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  # checkov:skip=CKV_AWS_145: S3 server access logging requires the target bucket to use
  # SSE-S3 — AWS does not support SSE-KMS for log-delivery target buckets.
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "expire-old-access-logs"
    status = "Enabled"

    expiration {
      days = 365
    }
  }
}

resource "aws_s3_bucket_notification" "access_logs" {
  bucket      = aws_s3_bucket.access_logs.id
  eventbridge = true
}

############################################
# AWS Config
############################################

resource "aws_config_configuration_recorder" "this" {
  name     = "${var.name_prefix}-config-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "this" {
  name           = "${var.name_prefix}-config-channel"
  s3_bucket_name = aws_s3_bucket.config.id

  depends_on = [aws_config_configuration_recorder.this]
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.this]
}

resource "aws_s3_bucket" "config" {
  bucket = "${var.name_prefix}-config-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-config-logs"
  })

  # checkov:skip=CKV_AWS_144: see cloudtrail bucket above — replication is environment-specific
  # and opt-in, not a sane default for a reusable module.
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket                  = aws_s3_bucket.config.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "config" {
  bucket = aws_s3_bucket.config.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  bucket = aws_s3_bucket.config.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.logs.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_logging" "config" {
  bucket        = aws_s3_bucket.config.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "config-bucket/"
}

resource "aws_s3_bucket_lifecycle_configuration" "config" {
  bucket = aws_s3_bucket.config.id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_notification" "config" {
  bucket      = aws_s3_bucket.config.id
  eventbridge = true
}

resource "aws_iam_role" "config" {
  name               = "${var.name_prefix}-config-role"
  assume_role_policy = data.aws_iam_policy_document.config_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "config_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_s3" {
  name   = "${var.name_prefix}-config-s3-delivery"
  role   = aws_iam_role.config.id
  policy = data.aws_iam_policy_document.config_s3_delivery.json
}

data "aws_iam_policy_document" "config_s3_delivery" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.config.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.config.arn]
  }
}

############################################
# GuardDuty
############################################

resource "aws_guardduty_detector" "this" {
  count  = var.enable_guardduty ? 1 : 0
  enable = true

  # checkov:skip=CKV2_AWS_3: This module configures GuardDuty at the member-account level.
  # Org-wide auto-enablement for new accounts is configured once, in the GuardDuty delegated
  # administrator account, via aws_guardduty_organization_configuration — that's a separate,
  # org-level concern outside a per-account baseline module's scope.

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = var.enable_eks_protection
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = var.tags
}

############################################
# SCP attachment (member accounts only — SCPs must already exist in the org's
# management account; this module attaches, it does not author, SCP content)
############################################

resource "aws_organizations_policy_attachment" "scp" {
  for_each  = var.attach_scp_ids
  policy_id = each.value
  target_id = var.account_id
}
