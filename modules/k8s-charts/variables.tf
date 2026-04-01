variable "applications" {
  description = <<-EOT
    Map of Helm chart releases to deploy. The map key becomes the Helm release name
    (e.g. "karpenter", "metrics-server", "external-secrets").
  EOT

  type = map(object({
    repository       = string
    chart            = string
    version          = string
    namespace        = optional(string, "default")
    create_namespace = optional(bool, true)
    values           = optional(string, "")      # raw YAML values passed to the chart
    set              = optional(map(string), {}) # individual key=value overrides
    atomic           = optional(bool, true)
    wait             = optional(bool, true)
    timeout          = optional(number, 300)
  }))

  default = {}
}
