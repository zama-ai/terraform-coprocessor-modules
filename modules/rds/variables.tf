variable "partner_name" {
  description = "Partner identifier, used for resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. testnet, mainnet)."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to deploy RDS into."
  type        = string
  default     = null
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the RDS subnet group."
  type        = list(string)
  default     = []
}

variable "private_subnet_cidr_blocks" {
  description = "CIDR blocks of private subnets, merged into RDS security group ingress."
  type        = list(string)
  default     = []
}

variable "rds" {
  description = <<-EOT
    RDS instance configuration. Set enabled = false to skip all RDS resources.
  EOT

  type = object({
    enabled = optional(bool, false)

    # Naming
    db_name             = optional(string, null)
    identifier_override = optional(string, null)

    # Engine
    engine         = optional(string, "postgres")
    engine_version = optional(string, "17")

    # Instance
    instance_class        = optional(string, "db.m5.4xlarge")
    allocated_storage     = optional(number, 400)
    max_allocated_storage = optional(number, 1000)
    multi_az              = optional(bool, false)
    port                  = optional(number, 5432)

    # Credentials
    username                            = optional(string, "postgres")
    manage_master_user_password         = optional(bool, true)   # true = Secrets Manager managed (recommended)
    password_wo                         = optional(string, null) # write-only; only used when manage_master_user_password = false
    password_wo_version                 = optional(number, 1)    # increment to rotate a non-managed password
    enable_master_password_rotation     = optional(bool, true)
    master_password_rotation_days       = optional(number, 7)
    iam_database_authentication_enabled = optional(bool, true)

    # Maintenance & backups
    maintenance_window      = optional(string, "Mon:00:00-Mon:03:00")
    backup_retention_period = optional(number, 30)
    deletion_protection     = optional(bool, true)

    # Monitoring
    monitoring_interval          = optional(number, 60)
    create_monitoring_role       = optional(bool, true)
    monitoring_role_name         = optional(string, null)
    existing_monitoring_role_arn = optional(string, null)

    # Parameters
    parameters = optional(list(object({
      name  = string
      value = string
    })), [])

    # Security group
    additional_allowed_cidr_blocks = optional(list(string), [])
  })

  default = { enabled = false }
}
