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

variable "kms_key_arn" {
  description = "ARN of the coprocessor KMS keypair from the kms module. Required when any service account sets kms_key_access = true."
  type        = string
  default     = null
}

variable "rds_client_security_group_id" {
  description = "ID of the rds-client security group from the rds module. Required when k8s.security_group_policies.rds_client.enabled = true; used as the groupIds value in the SecurityGroupPolicy resources that label pods for RDS access."
  type        = string
  default     = null
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
      # coprocessor: legacy IRSA role with S3 access (s3:*Object + s3:ListBucket).
      coprocessor = optional(object({
        enabled = optional(bool, false)
        # Key in var.s3_bucket_arns to grant access to.
        s3_bucket_key = optional(string, "coprocessor")
      }), {})

      # sns_worker: IRSA role with S3 access (s3:*Object + s3:ListBucket).
      sns_worker = optional(object({
        enabled = optional(bool, true)
        # Key in var.s3_bucket_arns to grant access to.
        s3_bucket_key = optional(string, "coprocessor")
      }), {})

      # db_admin: RDS master secrets and read-only access to explicit source buckets.
      # No KMS permissions. Null selects the mainnet/testnet bootstrap bucket for var.environment.
      db_admin = optional(object({
        enabled            = optional(bool, true)
        source_bucket_arns = optional(set(string), null)
      }), {})

      # tx_sender: IRSA role with KMS Sign/Verify on the coprocessor keypair.
      tx_sender = optional(object({
        enabled        = optional(bool, true)
        kms_key_access = optional(bool, true)
      }), {})

      # s3_migrate: IRSA role for a one-off bulk copy of an existing ciphertext
      # corpus into the coprocessor bucket. Created in the coproc-admin
      # namespace alongside db_admin.
      s3_migrate = optional(object({
        enabled = optional(bool, false)
        # Key in var.s3_bucket_arns to grant write access to (the destination).
        s3_bucket_key = optional(string, "coprocessor")
      }), {})

      # Custom service accounts beyond the built-ins.
      # An entry with the same key as a built-in overrides it entirely, except db-admin.
      # Every entry creates an IRSA role + policy.
      extra = optional(map(object({
        name                   = string
        namespace              = optional(string, null) # defaults to k8s.default_namespace
        iam_role_name_override = optional(string, null) # overrides computed "<key>-<partner_name>-<environment>"
        s3_bucket_access = optional(map(object({
          actions = list(string)
        })), {})
        rds_master_secret_access = optional(bool, false)
        kms_key_access           = optional(bool, false)
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

    # SecurityGroupPolicy resources for EKS Security Groups for Pods (SGP).
    # The CRD is installed automatically by EKS via the VPC Resource Controller.
    # Pods opt in by carrying the matching label on their pod template.
    security_group_policies = optional(object({
      # rds_client: built-in policy that attaches the rds-client SG to any pod
      # carrying the configured label. Created once per listed namespace.
      rds_client = optional(object({
        enabled = optional(bool, true)
        namespaces = optional(list(string), [
          "coproc-admin", "coproc", "gw-blockchain", "eth-blockchain", "polygon-blockchain", "monitoring"
        ])
        pod_label_key   = optional(string, "network/rds-client")
        pod_label_value = optional(string, "true")
      }), {})

      # Custom SecurityGroupPolicy resources beyond the built-ins.
      extra = optional(map(object({
        namespace          = string
        pod_selector       = map(string)
        security_group_ids = list(string)
      })), {})
    }), {})
  })

  default = { enabled = false }

  validation {
    condition = (
      !var.k8s.enabled || !var.k8s.service_accounts.db_admin.enabled ||
      (var.k8s.service_accounts.db_admin.source_bucket_arns == null
        ? contains(["mainnet", "testnet"], var.environment)
      : length(var.k8s.service_accounts.db_admin.source_bucket_arns) > 0)
    )
    error_message = "Enabled db-admin requires environment mainnet/testnet for the default bootstrap bucket, or a nonempty explicit db_admin.source_bucket_arns override."
  }

  validation {
    condition = var.k8s.service_accounts.db_admin.source_bucket_arns == null ? true : alltrue([
      for arn in var.k8s.service_accounts.db_admin.source_bucket_arns :
      can(regex("^arn:aws(-[a-z0-9-]+)?:s3:::[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", arn))
    ])
    error_message = "db_admin.source_bucket_arns must contain S3 bucket ARNs without wildcards, object paths, or prefixes (for example arn:aws:s3:::bootstrap-data)."
  }

  # Reserve the built-in identity so extra cannot restore wildcard S3 or KMS access.
  validation {
    condition = !var.k8s.enabled || alltrue([
      for key, account in var.k8s.service_accounts.extra :
      key != "db-admin" && !(account.name == "db-admin" && coalesce(account.namespace, var.k8s.default_namespace) == "coproc-admin")
    ])
    error_message = "The db-admin key and coproc-admin/db-admin identity are reserved; configure service_accounts.db_admin instead of overriding it through extra."
  }
}
