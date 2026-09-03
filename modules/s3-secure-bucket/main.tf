############################################
# s3-secure-bucket
#
# Opinionated S3 bucket: encrypted (KMS by default), versioned, public access blocked,
# access-logged to a separate bucket, and with an optional lifecycle policy.
############################################

data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name

  tags = merge(var.tags, {
    Name = var.bucket_name
  })

  # checkov:skip=CKV_AWS_144: Cross-region replication needs a pre-provisioned destination
  # bucket + IAM role that are environment-specific; not a sane default for a reusable module.
  # Add aws_s3_bucket_replication_configuration in the calling root config if needed.
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_kms_key" "this" {
  count                   = var.kms_key_arn == null ? 1 : 0
  description             = "KMS key for ${var.bucket_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_key_policy[0].json
  tags                    = var.tags
}

data "aws_iam_policy_document" "kms_key_policy" {
  count = var.kms_key_arn == null ? 1 : 0

  statement {
    sid    = "AllowRootAccountFullAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    # checkov:skip=CKV_AWS_109: AWS's own documented default KMS key policy statement — grants
    # the account's IAM policies control over the key so it stays manageable/rotatable, not
    # direct data access.
    # checkov:skip=CKV_AWS_111: same rationale — key administration, not unconstrained write.
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowS3Encrypt"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
    resources = ["*"]
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.this[0].arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_logging" "this" {
  count  = var.access_log_bucket != null ? 1 : 0
  bucket = aws_s3_bucket.this.id

  target_bucket = var.access_log_bucket
  target_prefix = "${var.bucket_name}/"
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  # Always present, regardless of user-supplied lifecycle_rules, so incomplete multipart
  # uploads don't accumulate storage cost/clutter indefinitely.
  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = "Enabled"

      dynamic "transition" {
        for_each = lookup(rule.value, "transitions", [])
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      dynamic "expiration" {
        for_each = lookup(rule.value, "expiration_days", null) != null ? [1] : []
        content {
          days = rule.value.expiration_days
        }
      }
    }
  }
}

resource "aws_s3_bucket_notification" "this" {
  bucket      = aws_s3_bucket.this.id
  eventbridge = true
}

data "aws_iam_policy_document" "deny_insecure_transport" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "deny_insecure_transport" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.deny_insecure_transport.json
}
