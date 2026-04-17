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

output "rds_master_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the RDS master user password. Null when manage_master_user_password = false or rds.enabled = false."
  value       = var.rds.enabled && var.rds.manage_master_user_password ? module.rds_instance[0].db_instance_master_user_secret_arn : null
}
