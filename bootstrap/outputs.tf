output "state_bucket_name" {
  description = "S3 bucket to use as the `bucket` value in every other root config's backend \"s3\" block."
  value       = module.state_bucket.bucket_id
}

output "state_bucket_arn" {
  description = "ARN of the state bucket."
  value       = module.state_bucket.bucket_arn
}

output "lock_table_name" {
  description = "DynamoDB table to use as the `dynamodb_table` value in every other root config's backend \"s3\" block."
  value       = aws_dynamodb_table.lock.name
}

output "lock_table_arn" {
  description = "ARN of the DynamoDB lock table."
  value       = aws_dynamodb_table.lock.arn
}
