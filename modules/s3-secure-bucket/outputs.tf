output "bucket_id" {
  description = "The bucket name."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "The bucket ARN."
  value       = aws_s3_bucket.this.arn
}

output "kms_key_arn" {
  description = "The KMS key ARN used for encryption (either the provided one or the one created by this module)."
  value       = var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.this[0].arn
}
