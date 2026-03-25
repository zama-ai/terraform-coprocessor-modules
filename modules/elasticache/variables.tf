variable "partner_name" {
  description = "Partner identifier, used for resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. testnet, mainnet)."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to deploy ElastiCache into."
  type        = string
  default     = null
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the ElastiCache subnet group."
  type        = list(string)
  default     = []
}

variable "private_subnet_cidr_blocks" {
  description = "CIDR blocks of private subnets, merged into ElastiCache security group ingress."
  type        = list(string)
  default     = []
}

variable "elasticache" {
  description = <<-EOT
    ElastiCache (Valkey/Redis) replication group configuration.
    Set enabled = false to skip all ElastiCache resources.

    Two deployment profiles:
      Testnet: node_type = cache.r7g.large,   data_tiering_enabled = false (default)
      Mainnet: node_type = cache.r6gd.xlarge,  data_tiering_enabled = true
  EOT

  type = object({
    enabled = optional(bool, false)

    # Naming
    replication_group_id = optional(string, null) # override computed "{partner_name}-{environment}" identifier

    # Engine
    engine         = optional(string, "valkey")
    engine_version = optional(string, "7.2")

    # Instance
    node_type            = optional(string, "cache.r7g.large")
    num_cache_clusters   = optional(number, 3) # 1 primary + 2 replicas
    port                 = optional(number, 6379)
    data_tiering_enabled = optional(bool, false)

    # High availability
    multi_az_enabled           = optional(bool, true)
    automatic_failover_enabled = optional(bool, true)

    # Encryption
    at_rest_encryption_enabled = optional(bool, true)
    transit_encryption_enabled = optional(bool, true)

    # Auth
    # NOTE: auth_token is stored in state as the AWS provider does not yet support write-only
    # auth_token_wo for aws_elasticache_replication_group. Track upstream progress:
    # https://github.com/hashicorp/terraform-provider-aws/pull/44260
    auth_token = optional(string, null) # requires transit_encryption_enabled = true

    # Maintenance & backups
    maintenance_window       = optional(string, "Mon:00:00-Mon:03:00")
    snapshot_retention_limit = optional(number, 7)
    snapshot_window          = optional(string, "03:00-05:00")

    # Parameters
    parameters = optional(list(object({
      name  = string
      value = string
    })), [])

    # Security group
    additional_allowed_cidr_blocks = optional(list(string), [])
  })

  default = { enabled = false }

  validation {
    condition     = !var.elasticache.data_tiering_enabled || can(regex("r6gd", var.elasticache.node_type))
    error_message = "data_tiering_enabled = true requires an r6gd node type (e.g. cache.r6gd.xlarge). Only the r6gd family supports data tiering."
  }

  validation {
    condition     = !var.elasticache.automatic_failover_enabled || var.elasticache.num_cache_clusters >= 2
    error_message = "automatic_failover_enabled requires at least 2 cache clusters (1 primary + 1 replica)."
  }
}
