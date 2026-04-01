<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~> 2.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.service_account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.service_account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.service_account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [kubernetes_namespace.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_service.external_name](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service) | resource |
| [kubernetes_service_account.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [kubernetes_storage_class_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/storage_class_v1) | resource |
| [aws_iam_policy_document.service_account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.service_account_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (e.g. testnet, mainnet). | `string` | n/a | yes |
| <a name="input_k8s"></a> [k8s](#input\_k8s) | Kubernetes coprocessor resource configuration. Set enabled = false to skip all resources. | <pre>object({<br/>    enabled = optional(bool, false)<br/><br/>    # Map of namespaces to create. The map key is the namespace name.<br/>    namespaces = optional(map(object({<br/>      labels      = optional(map(string), {})<br/>      annotations = optional(map(string), {})<br/>    })), {})<br/><br/>    # Fallback namespace for service accounts and ExternalName services that do not<br/>    # specify their own namespace. Does not need to be a key in namespaces (it may<br/>    # reference a pre-existing namespace).<br/>    default_namespace = optional(string, "coprocessor")<br/><br/>    # Map of service accounts to create.<br/>    # The map key is a short logical name (e.g. "sns-worker", "coprocessor").<br/>    # Service accounts with iam_policy_statements get a dedicated IRSA role; those<br/>    # without are created as plain service accounts with no role annotation.<br/>    service_accounts = optional(map(object({<br/>      # Kubernetes service account name<br/>      name = string<br/><br/>      # Namespace override; defaults to k8s.default_namespace when null<br/>      namespace = optional(string, null)<br/><br/>      # IAM role name override; defaults to "<key>-<partner_name>-<environment>"<br/>      iam_role_name_override = optional(string, null)<br/><br/>      # Map of logical bucket key → S3 actions to grant on that bucket.<br/>      # ARNs are resolved from var.s3_bucket_arns — no need to hardcode them in tfvars.<br/>      # Default actions: ["s3:*Object", "s3:ListBucket"]. Override per bucket as needed.<br/>      s3_bucket_access = optional(map(object({<br/>        actions = list(string)<br/>      })), {})<br/><br/>      # IAM policy statements for the IRSA role.<br/>      iam_policy_statements = optional(list(object({<br/>        sid       = optional(string, "")<br/>        effect    = string<br/>        actions   = list(string)<br/>        resources = list(string)<br/>        conditions = optional(list(object({<br/>          test     = string<br/>          variable = string<br/>          values   = list(string)<br/>        })), [])<br/>      })), [])<br/><br/>      labels      = optional(map(string), {})<br/>      annotations = optional(map(string), {})<br/>    })), {})<br/><br/>    # Map of StorageClass resources. The map key is the storage class name.<br/>    storage_classes = optional(map(object({<br/>      provisioner            = string<br/>      reclaim_policy         = optional(string, "Delete")<br/>      volume_binding_mode    = optional(string, "WaitForFirstConsumer")<br/>      allow_volume_expansion = optional(bool, true)<br/>      parameters             = optional(map(string), {})<br/>      annotations            = optional(map(string), {})<br/>      labels                 = optional(map(string), {})<br/>    })), {})<br/><br/>    # Map of ExternalName services — one per external dependency (RDS, ElastiCache, etc.).<br/>    # The map key becomes the Kubernetes service name (e.g. "coprocessor-db", "coprocessor-redis").<br/>    # The endpoint port is stripped automatically; the app connects on its own configured port.<br/>    # endpoint may be null to fall back to var.rds_endpoint (injected from the rds submodule).<br/>    external_name_services = optional(map(object({<br/>      endpoint    = optional(string, null) # host:port or bare hostname; null = use var.rds_endpoint<br/>      namespace   = optional(string, null) # defaults to k8s.default_namespace<br/>      annotations = optional(map(string), {})<br/>    })), {})<br/>  })</pre> | <pre>{<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | ARN of the EKS cluster OIDC provider, used to build IRSA trust policies. | `string` | n/a | yes |
| <a name="input_partner_name"></a> [partner\_name](#input\_partner\_name) | Partner identifier, used for IAM resource naming. | `string` | n/a | yes |
| <a name="input_rds_endpoint"></a> [rds\_endpoint](#input\_rds\_endpoint) | RDS instance hostname. Used as the external\_name for any ExternalName service whose endpoint is null. | `string` | `null` | no |
| <a name="input_s3_bucket_arns"></a> [s3\_bucket\_arns](#input\_s3\_bucket\_arns) | Map of logical bucket key to ARN from the s3 module. Referenced by service\_accounts[*].s3\_bucket\_access to generate S3 IAM statements automatically. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_iam_role_arns"></a> [iam\_role\_arns](#output\_iam\_role\_arns) | Map of logical service account key to IRSA IAM role ARN. Only includes service accounts with iam\_policy\_statements. |
| <a name="output_iam_role_names"></a> [iam\_role\_names](#output\_iam\_role\_names) | Map of logical service account key to IRSA IAM role name. Only includes service accounts with iam\_policy\_statements. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Kubernetes namespace for coprocessor resources. Null when k8s is disabled. |
| <a name="output_service_account_names"></a> [service\_account\_names](#output\_service\_account\_names) | Map of logical service account key to Kubernetes service account name. |
| <a name="output_storage_class_names"></a> [storage\_class\_names](#output\_storage\_class\_names) | Map of logical storage class key to storage class name. |
<!-- END_TF_DOCS -->
