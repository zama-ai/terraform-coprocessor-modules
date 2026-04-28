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

variable "s3_bucket_names" {
  description = "Map of logical bucket key to bucket name from the s3 module. Used to populate the coprocessor ConfigMap."
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

    # Fallback namespace for service accounts and ExternalName services that omit their own.
    default_namespace = optional(string, "coproc")

    # Namespaces
    namespaces = optional(map(object({
      enabled     = optional(bool, true)
      labels      = optional(map(string), {})
      annotations = optional(map(string), {})
    })), {})

    # Service accounts — built-in toggles + custom extras.
    service_accounts = optional(object({
      # coprocessor: IRSA role with S3 access (s3:*Object + s3:ListBucket).
      coprocessor = optional(object({
        enabled = optional(bool, true)
        # Key in var.s3_bucket_arns to grant access to.
        s3_bucket_key = optional(string, "coprocessor")
      }), {})

      # db_admin: IRSA role with RDS master secret (GetSecretValue + DescribeSecret).
      db_admin = optional(object({
        enabled = optional(bool, true)
      }), {})

      # Custom service accounts beyond the built-ins.
      # An entry with the same key as a built-in overrides it entirely.
      # Every entry creates an IRSA role + policy.
      extra = optional(map(object({
        name                   = string
        namespace              = optional(string, null) # defaults to k8s.default_namespace
        iam_role_name_override = optional(string, null) # overrides computed "<key>-<partner_name>-<environment>"
        s3_bucket_access = optional(map(object({
          actions = list(string)
        })), {})
        rds_master_secret_access = optional(bool, false)
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
    }), {})

    # Storage classes — built-in toggles + custom extras.
    storage_classes = optional(object({
      # gp3: encrypted EBS gp3, WaitForFirstConsumer, set as cluster default.
      gp3 = optional(object({
        enabled = optional(bool, true)
      }), {})

      # Custom storage classes beyond the built-ins.
      # An entry with the same key as a built-in overrides it entirely.
      extra = optional(map(object({
        provisioner            = string
        reclaim_policy         = optional(string, "Delete")
        volume_binding_mode    = optional(string, "WaitForFirstConsumer")
        allow_volume_expansion = optional(bool, true)
        parameters             = optional(map(string), {})
        annotations            = optional(map(string), {})
        labels                 = optional(map(string), {})
      })), {})
    }), {})

    # ExternalName services — map key becomes the Service name.
    # Endpoints resolved by the root module; port is stripped automatically.
    external_name_services = optional(map(object({
      enabled     = optional(bool, true)
      endpoint    = optional(string, null) # host:port or bare hostname
      namespace   = optional(string, null) # defaults to k8s.default_namespace
      annotations = optional(map(string), {})
    })), {})
  })

  default = { enabled = false }
}
