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

output "vpc_id" {
  description = "The VPC ID the ElastiCache replication group was deployed into (explicit input or discovered from cluster_name)."
  value       = local.vpc_id
}

output "private_subnet_ids" {
  description = "The private subnet IDs used for the ElastiCache subnet group (explicit input or discovered from cluster_name)."
  value       = local.private_subnet_ids
}

output "externalname_service_name" {
  description = "Name of the Kubernetes ExternalName service aliasing the primary endpoint, if created."
  value       = var.elasticache.enabled && var.externalname_service.enabled ? kubernetes_service.externalname[0].metadata[0].name : null
}
