variable "partner_name" {
  description = "Partner identifier, used for resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. prod, staging)."
  type        = string
}

variable "network_environment" {
  description = "Network environment identifier (e.g. mainnet, testnet)."
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "VPC ID to deploy RDS into. Falls back to EKS cluster VPC if null."
  type        = string
  default     = null
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the RDS subnet group."
  type        = list(string)
}

variable "private_subnet_cidr_blocks" {
  description = "CIDR blocks of private subnets, merged into RDS security group ingress."
  type        = list(string)
}

variable "rds" {
  description = <<-EOT
    RDS instance configuration. Set enabled = false to skip all RDS resources.
  EOT

  type = object({
    enabled = optional(bool, false)

    # Naming
    db_name             = string
    identifier_override = optional(string, null)

    # Engine
    engine         = optional(string, "postgres")
    engine_version = optional(number, 17)

    # Instance
    instance_class        = optional(string, "db.t4g.medium")
    allocated_storage     = optional(number, 20)
    max_allocated_storage = optional(number, 100)
    multi_az              = optional(bool, false)
    port                  = optional(number, 5432)

    # Credentials
    username                        = optional(string, "postgres")
    password                        = optional(string, null) # null = Secrets Manager managed
    enable_master_password_rotation = optional(bool, false)
    master_password_rotation_days   = optional(number, 7)

    # Maintenance & backups
    maintenance_window      = optional(string, "Mon:00:00-Mon:03:00")
    backup_retention_period = optional(number, 7)
    deletion_protection     = optional(bool, true)

    # Monitoring
    monitoring_interval      = optional(number, 60)
    create_monitoring_role   = optional(bool, true)
    monitoring_role_name     = optional(string, null)
    monitoring_role_arn      = optional(string, null)

    # Parameters
    parameters = optional(list(object({
      name  = string
      value = string
    })), [])

    # Security group
    allowed_cidr_blocks = optional(list(string), [])
  })

  default = { db_name = "", enabled = false }
}