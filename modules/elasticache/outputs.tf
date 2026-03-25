output "replication_group_id" {
  description = "The ID of the ElastiCache replication group."
  value       = var.elasticache.enabled ? module.elasticache[0].replication_group_id : null
}

output "replication_group_arn" {
  description = "The ARN of the ElastiCache replication group."
  value       = var.elasticache.enabled ? module.elasticache[0].replication_group_arn : null
}

output "primary_endpoint_address" {
  description = "The primary endpoint address of the replication group."
  value       = var.elasticache.enabled ? module.elasticache[0].replication_group_primary_endpoint_address : null
}

output "reader_endpoint_address" {
  description = "The reader endpoint address of the replication group (load-balanced across replicas)."
  value       = var.elasticache.enabled ? module.elasticache[0].replication_group_reader_endpoint_address : null
}

output "port" {
  description = "The port the ElastiCache replication group is listening on."
  value       = var.elasticache.enabled ? module.elasticache[0].replication_group_port : null
}

output "security_group_id" {
  description = "The ID of the ElastiCache security group."
  value       = var.elasticache.enabled ? module.elasticache[0].security_group_id : null
}
