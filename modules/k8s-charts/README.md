<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 3.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | ~> 3.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~> 2.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.irsa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.irsa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.irsa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [helm_release.apps](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.crds](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_manifest.additional](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_namespace.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_service_account.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [aws_iam_policy_document.irsa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.irsa_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_applications"></a> [applications](#input\_applications) | Map of system-level applications to deploy. The map key is the logical application name<br/>and becomes the Helm release name.<br/><br/>Each application may have any combination of:<br/>  - namespace: the Kubernetes namespace the application lives in (required)<br/>  - service\_account: a Kubernetes service account to create (optional)<br/>  - irsa: an IAM role for service account (IRSA) with policy statements (optional)<br/>  - helm\_chart: a Helm chart release (optional)<br/>  - additional\_manifests: raw YAML manifests applied after the Helm chart (optional)<br/><br/>NOTE: additional\_manifests that reference custom CRDs (e.g. ClusterSecretStore,<br/>ExternalSecret) require those CRDs to exist at plan time. On a net-new cluster,<br/>two applies are needed:<br/>  1st apply — installs the Helm chart (CRDs land)<br/>  2nd apply — creates CRD-dependent manifests | <pre>map(object({<br/>    # Kubernetes namespace the application lives in. Required.<br/>    namespace = object({<br/>      name   = string<br/>      create = optional(bool, false)<br/>    })<br/><br/>    # Kubernetes service account. When create = true and irsa.enabled = true,<br/>    # the IRSA role ARN is automatically injected as an annotation.<br/>    service_account = optional(object({<br/>      create      = optional(bool, false)<br/>      name        = optional(string, null)<br/>      labels      = optional(map(string), {})<br/>      annotations = optional(map(string), {})<br/>    }), null)<br/><br/>    # IAM role for service account (IRSA). Requires oidc_provider_arn to be set.<br/>    irsa = optional(object({<br/>      enabled   = optional(bool, false)<br/>      role_name = optional(string, null) # defaults to "<app_key>-<partner_name>-<environment>"<br/>      policy_statements = optional(list(object({<br/>        sid       = optional(string, "")<br/>        effect    = string<br/>        actions   = list(string)<br/>        resources = list(string)<br/>      })), [])<br/>    }), { enabled = false })<br/><br/>    # Helm chart release.<br/>    helm_chart = optional(object({<br/>      enabled          = optional(bool, true)<br/>      crd_chart        = optional(bool, false) # When true, this release is deployed before all non-CRD releases.<br/>      repository       = string<br/>      chart            = string<br/>      version          = string<br/>      values           = optional(string, "")      # inline YAML values<br/>      set              = optional(map(string), {}) # individual key=value overrides<br/>      create_namespace = optional(bool, false)<br/>      atomic           = optional(bool, true)<br/>      wait             = optional(bool, true)<br/>      timeout          = optional(number, 300)<br/>    }), null)<br/><br/>    # Raw YAML manifests applied after the Helm chart.<br/>    # Map key is a logical name; value is raw YAML content (single Kubernetes resource per entry).<br/>    # Use the placeholder __region__ anywhere a region string is needed — it is substituted<br/>    # with the current AWS provider region at apply time.<br/>    additional_manifests = optional(object({<br/>      enabled   = optional(bool, false)<br/>      manifests = optional(map(string), {})<br/>    }), { enabled = false })<br/>  }))</pre> | `{}` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (e.g. testnet, mainnet). | `string` | n/a | yes |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | ARN of the EKS cluster OIDC provider. Required when any application has irsa.enabled = true. | `string` | `""` | no |
| <a name="input_partner_name"></a> [partner\_name](#input\_partner\_name) | Partner identifier, used for IAM resource naming. | `string` | n/a | yes |
| <a name="input_set_computed"></a> [set\_computed](#input\_set\_computed) | Per-application helm set overrides injected by the root module from computed values (e.g. cluster name, queue ARN). Merged on top of helm\_chart.set — not intended to be set in tfvars. | `map(map(string))` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_helm_release_statuses"></a> [helm\_release\_statuses](#output\_helm\_release\_statuses) | Map of application name to Helm release status. |
| <a name="output_irsa_role_arns"></a> [irsa\_role\_arns](#output\_irsa\_role\_arns) | Map of application name to IRSA IAM role ARN. Only populated for applications with irsa.enabled = true. |
| <a name="output_namespace_names"></a> [namespace\_names](#output\_namespace\_names) | Map of application name to namespace name, for namespaces created by this module. |
| <a name="output_service_account_names"></a> [service\_account\_names](#output\_service\_account\_names) | Map of application name to service account name, for service accounts created by this module. |
<!-- END_TF_DOCS -->
