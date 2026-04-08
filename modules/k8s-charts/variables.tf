variable "partner_name" {
  description = "Partner identifier, used for IAM resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. testnet, mainnet)."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster OIDC provider. Required when any application has irsa.enabled = true."
  type        = string
  default     = ""
}

variable "set_computed" {
  description = "Per-application helm set overrides injected by the root module from computed values (e.g. cluster name, queue ARN). Merged on top of helm_chart.set — not intended to be set in tfvars."
  type        = map(map(string))
  default     = {}
}

variable "applications" {
  description = <<-EOT
    Map of system-level applications to deploy. The map key is the logical application name
    and becomes the Helm release name.

    Each application may have any combination of:
      - namespace: the Kubernetes namespace the application lives in (required)
      - service_account: a Kubernetes service account to create (optional)
      - irsa: an IAM role for service account (IRSA) with policy statements (optional)
      - helm_chart: a Helm chart release (optional)
      - additional_manifests: raw YAML manifests applied after the Helm chart (optional)

    NOTE: additional_manifests that reference custom CRDs (e.g. ClusterSecretStore,
    ExternalSecret) require those CRDs to exist at plan time. On a net-new cluster,
    two applies are needed:
      1st apply — installs the Helm chart (CRDs land)
      2nd apply — creates CRD-dependent manifests
  EOT

  type = map(object({
    # Kubernetes namespace the application lives in. Required.
    namespace = object({
      name   = string
      create = optional(bool, false)
    })

    # Kubernetes service account. When create = true and irsa.enabled = true,
    # the IRSA role ARN is automatically injected as an annotation.
    service_account = optional(object({
      create      = optional(bool, false)
      name        = optional(string, null)
      labels      = optional(map(string), {})
      annotations = optional(map(string), {})
    }), null)

    # IAM role for service account (IRSA). Requires oidc_provider_arn to be set.
    irsa = optional(object({
      enabled   = optional(bool, false)
      role_name = optional(string, null) # defaults to "<app_key>-<partner_name>-<environment>"
      policy_statements = optional(list(object({
        sid       = optional(string, "")
        effect    = string
        actions   = list(string)
        resources = list(string)
      })), [])
    }), { enabled = false })

    # Helm chart release.
    helm_chart = optional(object({
      enabled          = optional(bool, true)
      crd_chart        = optional(bool, false) # When true, this release is deployed before all non-CRD releases.
      repository       = string
      chart            = string
      version          = string
      values           = optional(string, "")      # inline YAML values
      set              = optional(map(string), {}) # individual key=value overrides
      create_namespace = optional(bool, false)
      atomic           = optional(bool, true)
      wait             = optional(bool, true)
      timeout          = optional(number, 300)
    }), null)

    # Raw YAML manifests applied after the Helm chart.
    # Map key is a logical name; value is raw YAML content (single Kubernetes resource per entry).
    # Use the placeholder __region__ anywhere a region string is needed — it is substituted
    # with the current AWS provider region at apply time.
    additional_manifests = optional(object({
      enabled   = optional(bool, false)
      manifests = optional(map(string), {})
    }), { enabled = false })
  }))

  default = {}
}
