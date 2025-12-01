variable "network_environment" {
  description = "Coprocessor network environment that determines region constraints"
  type        = string
  default     = "testnet"
  validation {
    condition     = contains(["testnet", "mainnet"], var.network_environment)
    error_message = "Network environment must be either 'testnet' or 'mainnet'."
  }
}

# Tagging
variable "tags" {
  type        = map(string)
  description = "A map of tags to assign to the resource"
  default = {
    "terraform"              = "true"
    "module"                 = "coprocessor-infra"
    "app.kubernetes.io/name" = "coprocessor"
  }
}

variable "cluster_name" {
  type        = string
  description = "The name of the EKS cluster for IRSA configuration"
}


# Kubernetes Namespace Configuration
variable "k8s_coprocessor_namespace" {
  type        = string
  description = "The Kubernetes namespace for coprocessor resources"
  default     = "coprocessor"
}

variable "create_coprocessor_namespace" {
  type        = bool
  description = "Whether to create the Kubernetes namespace"
  default     = true
}

variable "namespace_labels" {
  type        = map(string)
  description = "Additional labels to apply to the namespace"
  default     = {}
}

variable "namespace_annotations" {
  type        = map(string)
  description = "Additional annotations to apply to the namespace"
  default     = {}
}
# Kubernetes Service Account Configuration
variable "k8s_coprocessor_service_account_name" {
  type        = string
  description = "The name of the Kubernetes service account for Coprocessor party"
}

variable "k8s_coprocessor_gw_listener_service_account_name" {
  type        = string
  description = "The name of the Kubernetes service account for Coprocessor gw listener"
}

variable "create_service_account" {
  type        = bool
  description = "Whether to create the Kubernetes service account (should be false when using IRSA as IRSA creates it)"
  default     = true
}

variable "service_account_labels" {
  type        = map(string)
  description = "Additional labels to apply to the service account"
  default     = {}
}

variable "service_account_annotations" {
  type        = map(string)
  description = "Additional annotations to apply to the service account (excluding IRSA annotations which are handled automatically)"
  default     = {}
}

variable "coprocessor_role_name" {
  type        = string
  description = "The name of the IAM role for the coprocessor"
  default     = ""
  validation {
    condition     = length(var.coprocessor_role_name) <= 64
    error_message = "Coprocessor role name must be 64 characters or less."
  }
}

variable "coprocessor_gw_listener_role_name" {
  type        = string
  description = "The name of the IAM role for the coprocessor gw listener"
  default     = ""
  validation {
    condition     = length(var.coprocessor_gw_listener_role_name) <= 64
    error_message = "Coprocessor gw listener role name must be 64 characters or less."
  }
}

# ******************************************************
# S3 bucket
# ******************************************************
variable "bucket_prefix" {
  type        = string
  description = "The prefix for the S3 bucket names"
  default     = "coprocessor-bucket"
}

# ******************************************************
# RDS instance
# ******************************************************
variable "enable_rds" {
  type        = bool
  description = "Whether to create the RDS instance"
  default     = true
}

variable "rds_prefix" {
  description = "Name organization prefix (e.g., 'zama')."
  type        = string
  default     = "zama"
}

variable "rds_vpc_id" {
  description = "VPC ID hosting the RDS instance."
  type        = string
  default     = null
}

variable "rds_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach the database port."
  type        = list(string)
  default     = []
}

variable "rds_engine" {
  type        = string
  description = "Engine name (e.g., postgres, mysql)."
  default     = "postgres"
}

variable "rds_engine_version" {
  type        = string
  description = "Exact engine version string."
  default     = "17.2"
}

variable "rds_instance_class" {
  type        = string
  description = "DB instance class (e.g., db.t4g.medium)."
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  type        = number
  description = "Allocated storage in GiB."
  default     = 20
}

variable "rds_max_allocated_storage" {
  type        = number
  description = "Max autoscaled storage in GiB."
  default     = 1000
}

variable "rds_db_name" {
  type        = string
  default     = "coprocessor"
  description = "Optional initial database name."
}

variable "rds_backup_retention_period" {
  description = "Number of days to retain RDS automated backups (0 to 35)"
  type        = number
  default     = 7
}

variable "rds_maintenance_window" {
  description = "Weekly maintenance window for RDS instance (e.g., 'sun:05:00-sun:06:00')"
  type        = string
  default     = null
}

variable "rds_multi_az" {
  description = "Whether to enable Multi-AZ deployment for RDS instance for high availability"
  type        = bool
  default     = false
}

variable "rds_deletion_protection" {
  description = "Whether to enable deletion protection for RDS instance"
  type        = bool
  default     = false
}

variable "rds_db_password" {
  description = "RDS password to be set from inputs (must be longer than 8 chars), will disable RDS automatic SecretManager password"
  type        = string
  default     = null
}

variable "rds_enable_master_password_rotation" {
  description = "Whether to manage the master user password rotation. By default, false on creation, rotation is managed by RDS. There is not currently no way to disable this on initial creation even when set to false. Setting this value to false after previously having been set to true will disable automatic rotation."
  type        = bool
  default     = true
}

variable "rds_master_password_rotation_days" {
  description = "Number of days between automatic scheduled rotations of the secret, default is set to the maximum allowed value of 1000 days"
  type        = number
  default     = 1000
}

variable "rds_monitoring_interval" {
  description = "Enhanced monitoring interval in seconds (0, 1, 5, 10, 15, 30, 60)"
  type        = number
  default     = 0
}

variable "rds_monitoring_role_arn" {
  description = "ARN of IAM role for RDS enhanced monitoring (required if monitoring_interval > 0)"
  type        = string
  default     = null
}

# Parameter group
variable "rds_parameters" {
  description = "List of DB parameter maps for the parameter group."
  type        = list(map(string))
  default = [{
    name  = "rds.force_ssl"
    value = "0"
  }]
}

variable "rds_create_externalname_service" {
  description = "Whether to create a Kubernetes ExternalName service for RDS database access"
  type        = bool
  default     = false
}

variable "rds_externalname_service_name" {
  description = "Name of the Kubernetes ExternalName service for RDS database"
  type        = string
  default     = "coprocessor-db-external"
}

variable "rds_externalname_service_namespace" {
  description = "Kubernetes namespace for the RDS ExternalName service"
  type        = string
  default     = "coprocessor"
}

# Optional override for RDS identifier
variable "rds_identifier_override" {
  type        = string
  default     = null
  description = "Explicit DB identifier. If null, a normalized name is derived from prefix+environment+identifier."
}

variable "rds_port" {
  type        = number
  default     = 5432
  description = "Port for the RDS instance"
}

variable "rds_username" {
  type        = string
  default     = "zws"
  description = "Username for the RDS instance"
}

variable "rds_create_monitoring_role" {
  type        = bool
  default     = true
  description = "Whether to create the RDS monitoring role"
}

variable "rds_monitoring_role_name" {
  type        = string
  default     = "rds-monitoring-role"
  description = "Name of the monitoring role to create"
}
