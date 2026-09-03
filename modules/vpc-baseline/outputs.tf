output "vpc_id" {
  description = "ID of the created VPC."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Map of AZ => public subnet ID."
  value       = { for az, subnet in aws_subnet.public : az => subnet.id }
}

output "private_subnet_ids" {
  description = "Map of AZ => private subnet ID."
  value       = { for az, subnet in aws_subnet.private : az => subnet.id }
}

output "nat_gateway_ids" {
  description = "Map of key => NAT gateway ID (single 'shared' key if single_nat_gateway is true)."
  value       = { for k, nat in aws_nat_gateway.this : k => nat.id }
}
