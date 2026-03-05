output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs."
  value       = module.vpc.private_subnets
}

output "private_subnet_cidr_blocks" {
  description = "CIDR blocks of private subnets."
  value       = module.vpc.private_subnets_cidr_blocks
}

output "additional_subnet_ids" {
  description = "List of additional subnet IDs (empty list when not enabled)."
  value       = aws_subnet.additional[*].id
}
