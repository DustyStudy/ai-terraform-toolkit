output "permission_set_arn" {
  description = "ARN of the created permission set."
  value       = aws_ssoadmin_permission_set.this.arn
}

output "permission_set_name" {
  description = "Name of the created permission set."
  value       = aws_ssoadmin_permission_set.this.name
}
