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

variable "manifests_vars" {
  description = "Computed values injected into additional_manifests YAML by the root module. Supported placeholders: __region__ (always substituted), __cluster_name__, __node_role__."
  type = object({
    cluster_name = optional(string, "")
    node_role    = optional(string, "")
  })
  default = {}
}

variable "defaults" {
  description = <<-EOT
    Toggle built-in applications on/off with optional version/values overrides.
    All built-ins default to disabled except karpenter_nodepools, prometheus_operator_crds,
    metrics_server, and karpenter which default to enabled.

    Built-in applications:
      - karpenter_nodepools:          EC2NodeClass + NodePool manifests (no Helm chart)
      - prometheus_operator_crds:     Cluster-scoped Prometheus CRDs (must precede ServiceMonitor charts)
      - metrics_server:               Kubernetes Metrics Server
      - karpenter:                    Karpenter controller
      - k8s_monitoring:               Grafana k8s-monitoring (requires values with destination URLs)
      - prometheus_rds_exporter:      Prometheus RDS exporter (IRSA + Helm chart)
      - prometheus_postgres_exporter: Prometheus Postgres exporter
  EOT
  type = object({
    karpenter_nodepools = optional(object({
      enabled = optional(bool, true)
    }), {})
    prometheus_operator_crds = optional(object({
      enabled    = optional(bool, true)
      repository = optional(string, "https://prometheus-community.github.io/helm-charts")
      chart      = optional(string, "prometheus-operator-crds")
      version    = optional(string, "28.0.1")
    }), {})
    metrics_server = optional(object({
      enabled    = optional(bool, true)
      repository = optional(string, "https://kubernetes-sigs.github.io/metrics-server")
      chart      = optional(string, "metrics-server")
      version    = optional(string, "3.13.0")
      image_tag  = optional(string, "v0.8.0")
      values     = optional(string, "")
    }), {})
    karpenter = optional(object({
      enabled              = optional(bool, true)
      repository           = optional(string, "oci://public.ecr.aws/karpenter")
      chart                = optional(string, "karpenter")
      version              = optional(string, "1.8.2")
      controller_image_tag = optional(string, "v1.11.0")
      # Appended on top of baked-in defaults — use to override specific fields.
      values = optional(string, "")
    }), {})
    k8s_monitoring = optional(object({
      enabled                  = optional(bool, false)
      repository               = optional(string, "https://grafana.github.io/helm-charts")
      chart                    = optional(string, "k8s-monitoring")
      version                  = optional(string, "4.0.1")
      prometheus_url           = optional(string, "")
      loki_url                 = optional(string, "")
      otlp_url                 = optional(string, "")
      alloy_operator_image_tag = optional(string, "v0.5.3")
      alloy_image_tag          = optional(string, "v1.15.0")
      node_exporter_image_tag  = optional(string, "v1.11.0")
      # Appended after baked-in base + destinations — use for arbitrary additional overrides.
      values = optional(string, "")
    }), {})
    prometheus_rds_exporter = optional(object({
      enabled    = optional(bool, false)
      repository = optional(string, "oci://public.ecr.aws/qonto")
      chart      = optional(string, "prometheus-rds-exporter-chart")
      version    = optional(string, "0.16.0")
      values     = optional(string, "")
    }), {})
    prometheus_postgres_exporter = optional(object({
      enabled    = optional(bool, false)
      repository = optional(string, "https://prometheus-community.github.io/helm-charts")
      chart      = optional(string, "prometheus-postgres-exporter")
      version    = optional(string, "7.3.0")
      image_tag  = optional(string, "v0.19.1")
      values     = optional(string, "")
    }), {})
  })
  default = {}
}

variable "extra" {
  description = <<-EOT
    Additional custom applications to deploy alongside the built-ins.
    The map key is the logical application name and becomes the Helm release name.
    An entry here with the same key as a built-in overrides the built-in entirely.

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
    namespace = object({
      name   = string
      create = optional(bool, false)
    })
    service_account = optional(object({
      create      = optional(bool, false)
      name        = optional(string, null)
      labels      = optional(map(string), {})
      annotations = optional(map(string), {})
    }), null)
    irsa = optional(object({
      enabled   = optional(bool, false)
      role_name = optional(string, null)
      policy_statements = optional(list(object({
        sid       = optional(string, "")
        effect    = string
        actions   = list(string)
        resources = list(string)
      })), [])
    }), { enabled = false })
    helm_chart = optional(object({
      enabled          = optional(bool, true)
      crd_chart        = optional(bool, false)
      repository       = string
      chart            = string
      version          = string
      values           = optional(string, "")
      set              = optional(map(string), {})
      create_namespace = optional(bool, false)
      atomic           = optional(bool, true)
      wait             = optional(bool, true)
      timeout          = optional(number, 300)
    }), null)
    additional_manifests = optional(object({
      enabled   = optional(bool, false)
      manifests = optional(map(string), {})
    }), { enabled = false })
  }))
  default = {}
}
