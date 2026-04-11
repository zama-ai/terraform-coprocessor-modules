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
| <a name="input_defaults"></a> [defaults](#input\_defaults) | Toggle built-in applications on/off with optional version/values overrides.<br/>All built-ins default to disabled except karpenter\_nodepools, prometheus\_operator\_crds,<br/>metrics\_server, and karpenter which default to enabled.<br/><br/>Built-in applications:<br/>  - karpenter\_nodepools:          EC2NodeClass + NodePool manifests (no Helm chart)<br/>  - prometheus\_operator\_crds:     Cluster-scoped Prometheus CRDs (must precede ServiceMonitor charts)<br/>  - metrics\_server:               Kubernetes Metrics Server<br/>  - karpenter:                    Karpenter controller<br/>  - k8s\_monitoring:               Grafana k8s-monitoring (requires values with destination URLs)<br/>  - prometheus\_rds\_exporter:      Prometheus RDS exporter (IRSA + Helm chart)<br/>  - prometheus\_postgres\_exporter: Prometheus Postgres exporter | <pre>object({<br/>    karpenter_nodepools = optional(object({<br/>      enabled = optional(bool, true)<br/>    }), {})<br/>    prometheus_operator_crds = optional(object({<br/>      enabled = optional(bool, true)<br/>      version = optional(string, "28.0.1")<br/>    }), {})<br/>    metrics_server = optional(object({<br/>      enabled = optional(bool, true)<br/>      version = optional(string, "3.13.0")<br/>    }), {})<br/>    karpenter = optional(object({<br/>      enabled = optional(bool, true)<br/>      version = optional(string, "1.8.2")<br/>      # Appended on top of baked-in defaults — use to override specific fields.<br/>      values = optional(string, "")<br/>    }), {})<br/>    k8s_monitoring = optional(object({<br/>      enabled        = optional(bool, false)<br/>      version        = optional(string, "3.8.1")<br/>      prometheus_url = optional(string, "")<br/>      loki_url       = optional(string, "")<br/>      otlp_url       = optional(string, "")<br/>      # Appended after baked-in base + destinations — use for arbitrary additional overrides.<br/>      values = optional(string, "")<br/>    }), {})<br/>    prometheus_rds_exporter = optional(object({<br/>      enabled = optional(bool, false)<br/>      version = optional(string, "1.0.1")<br/>    }), {})<br/>    prometheus_postgres_exporter = optional(object({<br/>      enabled = optional(bool, false)<br/>      version = optional(string, "7.3.0")<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (e.g. testnet, mainnet). | `string` | n/a | yes |
| <a name="input_extra"></a> [extra](#input\_extra) | Additional custom applications to deploy alongside the built-ins.<br/>The map key is the logical application name and becomes the Helm release name.<br/>An entry here with the same key as a built-in overrides the built-in entirely.<br/><br/>Each application may have any combination of:<br/>  - namespace: the Kubernetes namespace the application lives in (required)<br/>  - service\_account: a Kubernetes service account to create (optional)<br/>  - irsa: an IAM role for service account (IRSA) with policy statements (optional)<br/>  - helm\_chart: a Helm chart release (optional)<br/>  - additional\_manifests: raw YAML manifests applied after the Helm chart (optional)<br/><br/>NOTE: additional\_manifests that reference custom CRDs (e.g. ClusterSecretStore,<br/>ExternalSecret) require those CRDs to exist at plan time. On a net-new cluster,<br/>two applies are needed:<br/>  1st apply — installs the Helm chart (CRDs land)<br/>  2nd apply — creates CRD-dependent manifests | <pre>map(object({<br/>    namespace = object({<br/>      name   = string<br/>      create = optional(bool, false)<br/>    })<br/>    service_account = optional(object({<br/>      create      = optional(bool, false)<br/>      name        = optional(string, null)<br/>      labels      = optional(map(string), {})<br/>      annotations = optional(map(string), {})<br/>    }), null)<br/>    irsa = optional(object({<br/>      enabled   = optional(bool, false)<br/>      role_name = optional(string, null)<br/>      policy_statements = optional(list(object({<br/>        sid       = optional(string, "")<br/>        effect    = string<br/>        actions   = list(string)<br/>        resources = list(string)<br/>      })), [])<br/>    }), { enabled = false })<br/>    helm_chart = optional(object({<br/>      enabled          = optional(bool, true)<br/>      crd_chart        = optional(bool, false)<br/>      repository       = string<br/>      chart            = string<br/>      version          = string<br/>      values           = optional(string, "")<br/>      set              = optional(map(string), {})<br/>      create_namespace = optional(bool, false)<br/>      atomic           = optional(bool, true)<br/>      wait             = optional(bool, true)<br/>      timeout          = optional(number, 300)<br/>    }), null)<br/>    additional_manifests = optional(object({<br/>      enabled   = optional(bool, false)<br/>      manifests = optional(map(string), {})<br/>    }), { enabled = false })<br/>  }))</pre> | `{}` | no |
| <a name="input_manifests_vars"></a> [manifests\_vars](#input\_manifests\_vars) | Computed values injected into additional\_manifests YAML by the root module. Supported placeholders: __region__ (always substituted), \_\_cluster\_name\_\_, \_\_node\_role\_\_. | <pre>object({<br/>    cluster_name = optional(string, "")<br/>    node_role    = optional(string, "")<br/>  })</pre> | `{}` | no |
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
