variable "partner_name" {
  description = "Partner identifier, used for IAM resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. testnet, mainnet)."
  type        = string
}

# ******************************************************
#  Cross-module wiring (from eks / rds / s3 outputs)
# ******************************************************
variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster OIDC provider, used to build IRSA trust policies."
  type        = string
}

variable "rds_endpoint" {
  description = "RDS instance hostname. Used as the external_name for any ExternalName service whose endpoint is null."
  type        = string
  default     = null
}

variable "s3_bucket_arns" {
  description = "Map of logical bucket key to ARN from the s3 module. Referenced by service_accounts[*].s3_bucket_access to generate S3 IAM statements automatically."
  type        = map(string)
  default     = {}
}

# ******************************************************
#  Module configuration
# ******************************************************
variable "k8s" {
  description = <<-EOT
    Kubernetes coprocessor resource configuration. Set enabled = false to skip all resources.
  EOT

  type = object({
    enabled = optional(bool, false)

    # Map of namespaces to create. The map key is the namespace name.
    namespaces = optional(map(object({
      labels      = optional(map(string), {})
      annotations = optional(map(string), {})
    })), {})

    # Fallback namespace for service accounts and ExternalName services that do not
    # specify their own namespace. Does not need to be a key in namespaces (it may
    # reference a pre-existing namespace).
    default_namespace = optional(string, "coprocessor")

    # Map of service accounts to create.
    # The map key is a short logical name (e.g. "sns-worker", "coprocessor").
    # Service accounts with iam_policy_statements get a dedicated IRSA role; those
    # without are created as plain service accounts with no role annotation.
    service_accounts = optional(map(object({
      # Kubernetes service account name
      name = string

      # Namespace override; defaults to k8s.default_namespace when null
      namespace = optional(string, null)

      # IAM role name override; defaults to "<key>-<partner_name>-<environment>"
      iam_role_name_override = optional(string, null)

      # Map of logical bucket key → S3 actions to grant on that bucket.
      # ARNs are resolved from var.s3_bucket_arns — no need to hardcode them in tfvars.
      # Default actions: ["s3:*Object", "s3:ListBucket"]. Override per bucket as needed.
      s3_bucket_access = optional(map(object({
        actions = list(string)
      })), {})

      # IAM policy statements for the IRSA role.
      iam_policy_statements = optional(list(object({
        sid       = optional(string, "")
        effect    = string
        actions   = list(string)
        resources = list(string)
        conditions = optional(list(object({
          test     = string
          variable = string
          values   = list(string)
        })), [])
      })), [])

      labels      = optional(map(string), {})
      annotations = optional(map(string), {})
    })), {})

    # Map of StorageClass resources. The map key is the storage class name.
    storage_classes = optional(map(object({
      provisioner            = string
      reclaim_policy         = optional(string, "Delete")
      volume_binding_mode    = optional(string, "WaitForFirstConsumer")
      allow_volume_expansion = optional(bool, true)
      parameters             = optional(map(string), {})
      annotations            = optional(map(string), {})
      labels                 = optional(map(string), {})
    })), {})

    # Map of ExternalName services — one per external dependency (RDS, ElastiCache, etc.).
    # The map key becomes the Kubernetes service name (e.g. "coprocessor-db", "coprocessor-redis").
    # The endpoint port is stripped automatically; the app connects on its own configured port.
    # endpoint may be null to fall back to var.rds_endpoint (injected from the rds submodule).
    external_name_services = optional(map(object({
      endpoint    = optional(string, null) # host:port or bare hostname; null = use var.rds_endpoint
      namespace   = optional(string, null) # defaults to k8s.default_namespace
      annotations = optional(map(string), {})
    })), {})
  })

  default = { enabled = false }
}
