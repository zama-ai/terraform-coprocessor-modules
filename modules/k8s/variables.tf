variable "partner_name" {
  description = "Partner identifier, used for IAM resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. testnet, mainnet)."
  type        = string
}

# ******************************************************
#  Cross-module wiring (from eks / rds outputs)
# ******************************************************
variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster OIDC provider, used to build IRSA trust policies."
  type        = string
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

      # IAM policy statements for the IRSA role.
      iam_policy_statements = optional(list(object({
        sid       = optional(string, "")
        effect    = optional(string, "Allow")
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

    # Map of ExternalName services — one per external dependency (RDS, ElastiCache, etc.).
    # The map key becomes the Kubernetes service name (e.g. "coprocessor-db", "coprocessor-redis").
    # The endpoint port is stripped automatically; the app connects on its own configured port.
    external_name_services = optional(map(object({
      endpoint    = string                 # host:port or bare hostname
      namespace   = optional(string, null) # defaults to k8s.default_namespace
      annotations = optional(map(string), {})
    })), {})
  })

  default = { enabled = false }
}
