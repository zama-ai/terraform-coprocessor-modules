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
  description = "CIDR blocks of private subnets, added as rds_server SG ingress. Subnet-level fallback for instance types that don't support EKS Security Groups for Pods (e.g. hpc7a)."
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

    # Database Insights (formerly Performance Insights)
    # Standard mode retains 7 days free; advanced mode retains 15 months and is
    # billed per vCPU. Valid retention values: 7, 31 * n (n = 1..23), or 731.
    performance_insights_enabled          = optional(bool, false)
    performance_insights_retention_period = optional(number, 7)
    performance_insights_kms_key_id       = optional(string, null)
    database_insights_mode                = optional(string, null)

    # Parameters
    # NOTE: rds.force_ssl = 0 is a temporary workaround for binary issues with
    # SSL connections; remove once resolved.
    parameters = optional(list(object({
      name  = string
      value = string
    })), [{ name = "rds.force_ssl", value = "0" }])

    # Security group
    # Break-glass CIDR ingress on the RDS server SG. Pod-originated traffic
    # should rely on the rds_client SG attached via SecurityGroupPolicy; only
    # use this for one-off bastion / migration access.
    additional_allowed_cidr_blocks = optional(list(string), [])
  })

  default = { enabled = false }

  # AWS rejects retention values outside this set with InvalidParameterValue.
  validation {
    condition = contains(
      concat([7, 731], [for n in range(1, 24) : n * 31]),
      var.rds.performance_insights_retention_period
    )
    error_message = "rds.performance_insights_retention_period must be 7, 731, or a multiple of 31 up to 713."
  }

  # Advanced mode is rejected at apply unless Performance Insights is on with
  # at least 15 months (465 days) of retention.
  validation {
    condition = (
      var.rds.database_insights_mode != "advanced"
      || (var.rds.performance_insights_enabled && var.rds.performance_insights_retention_period >= 465)
    )
    error_message = "rds.database_insights_mode = \"advanced\" requires performance_insights_enabled = true and performance_insights_retention_period >= 465."
  }

  validation {
    condition     = var.rds.database_insights_mode == null || contains(["standard", "advanced"], coalesce(var.rds.database_insights_mode, "standard"))
    error_message = "rds.database_insights_mode must be \"standard\", \"advanced\", or null."
  }
}
