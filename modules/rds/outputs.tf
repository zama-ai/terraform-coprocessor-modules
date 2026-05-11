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

output "rds_client_security_group_id" {
  description = "ID of the rds-client SG attached to pods (via SecurityGroupPolicy) that need DB access."
  value       = var.rds.enabled ? aws_security_group.rds_client[0].id : null
}

output "rds_server_security_group_id" {
  description = "ID of the rds-server SG attached to the RDS instance."
  value       = var.rds.enabled ? aws_security_group.rds_server[0].id : null
}

output "rds_master_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the RDS master user password. Null when manage_master_user_password = false or rds.enabled = false."
  value       = var.rds.enabled && var.rds.manage_master_user_password ? module.rds_instance[0].db_instance_master_user_secret_arn : null
}
