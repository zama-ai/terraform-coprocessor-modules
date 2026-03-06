output "db_instance_identifier" {
  description = "The RDS instance identifier."
  value       = var.rds.enabled ? module.rds_instance[0].db_instance_identifier : null
}

output "db_instance_arn" {
  description = "The ARN of the RDS instance."
  value       = var.rds.enabled ? module.rds_instance[0].db_instance_arn : null
}

output "db_instance_endpoint" {
  description = "The connection endpoint of the RDS instance (host:port)."
  value       = var.rds.enabled ? module.rds_instance[0].db_instance_endpoint : null
}

output "db_instance_address" {
  description = "The hostname of the RDS instance (without port)."
  value       = var.rds.enabled ? module.rds_instance[0].db_instance_address : null
}

output "db_instance_port" {
  description = "The port the RDS instance is listening on."
  value       = var.rds.enabled ? module.rds_instance[0].db_instance_port : null
}

output "db_instance_name" {
  description = "The name of the default database."
  value       = var.rds.enabled ? module.rds_instance[0].db_instance_name : null
}

output "security_group_id" {
  description = "The ID of the RDS security group."
  value       = var.rds.enabled ? module.rds_security_group[0].security_group_id : null
}
