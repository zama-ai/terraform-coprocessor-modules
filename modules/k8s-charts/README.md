<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | ~> 3.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.this](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_applications"></a> [applications](#input\_applications) | Map of Helm chart releases to deploy. The map key becomes the Helm release name<br/>(e.g. "karpenter", "metrics-server", "external-secrets"). | <pre>map(object({<br/>    repository       = string<br/>    chart            = string<br/>    version          = string<br/>    namespace        = optional(string, "default")<br/>    create_namespace = optional(bool, true)<br/>    values           = optional(string, "")      # raw YAML values passed to the chart<br/>    set              = optional(map(string), {}) # individual key=value overrides<br/>    atomic           = optional(bool, true)<br/>    wait             = optional(bool, true)<br/>    timeout          = optional(number, 300)<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_application_status"></a> [application\_status](#output\_application\_status) | Map of release name to Helm release status. |
<!-- END_TF_DOCS -->
