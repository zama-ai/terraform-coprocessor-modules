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

variable "rds_master_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the RDS master user password. Required when any service account sets rds_master_secret_access = true."
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

    # Namespaces
    namespaces = optional(map(object({
      labels      = optional(map(string), {})
      annotations = optional(map(string), {})
    })), {})

    # Fallback namespace for service accounts and ExternalName services that omit their own.
    default_namespace = optional(string, "coprocessor")

    # Service accounts — every entry creates an IRSA role + policy regardless of which access fields are set.
    service_accounts = optional(map(object({
      name                   = string
      namespace              = optional(string, null) # defaults to k8s.default_namespace
      iam_role_name_override = optional(string, null) # overrides computed "<key>-<partner_name>-<environment>"

      # S3 access — map key must match a key in var.s3.buckets
      s3_bucket_access = optional(map(object({
        actions = list(string)
      })), {})

      # RDS access — grants GetSecretValue + DescribeSecret on the RDS master secret
      rds_master_secret_access = optional(bool, false)

      # Custom IAM policy statements appended to the generated role
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

      # Metadata
      labels      = optional(map(string), {})
      annotations = optional(map(string), {})
    })), {})

    # Storage classes
    storage_classes = optional(map(object({
      provisioner            = string
      reclaim_policy         = optional(string, "Delete")
      volume_binding_mode    = optional(string, "WaitForFirstConsumer")
      allow_volume_expansion = optional(bool, true)
      parameters             = optional(map(string), {})
      annotations            = optional(map(string), {})
      labels                 = optional(map(string), {})
    })), {})

    # ExternalName services — map key becomes the Service name
    # Endpoints resolved by the root module; port is stripped automatically.
    external_name_services = optional(map(object({
      endpoint    = optional(string, null) # host:port or bare hostname
      namespace   = optional(string, null) # defaults to k8s.default_namespace
      annotations = optional(map(string), {})
    })), {})
  })

  default = { enabled = false }
}
