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
| [kubernetes_config_map.db_admin_secret_id](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map) | resource |
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
| <a name="input_k8s"></a> [k8s](#input\_k8s) | Kubernetes coprocessor resource configuration. Set enabled = false to skip all resources. | <pre>object({<br/>    enabled = optional(bool, false)<br/><br/>    # Fallback namespace for service accounts and ExternalName services that omit their own.<br/>    default_namespace = optional(string, "coproc")<br/><br/>    # Namespaces<br/>    namespaces = optional(map(object({<br/>      enabled     = optional(bool, true)<br/>      labels      = optional(map(string), {})<br/>      annotations = optional(map(string), {})<br/>    })), {})<br/><br/>    # Service accounts — built-in toggles + custom extras.<br/>    service_accounts = optional(object({<br/>      # coprocessor: IRSA role with S3 access (s3:*Object + s3:ListBucket).<br/>      coprocessor = optional(object({<br/>        enabled = optional(bool, true)<br/>        # Key in var.s3_bucket_arns to grant access to.<br/>        s3_bucket_key = optional(string, "coprocessor")<br/>      }), {})<br/><br/>      # db_admin: IRSA role with RDS master secret (GetSecretValue + DescribeSecret).<br/>      db_admin = optional(object({<br/>        enabled = optional(bool, true)<br/>      }), {})<br/><br/>      # Custom service accounts beyond the built-ins.<br/>      # An entry with the same key as a built-in overrides it entirely.<br/>      # Every entry creates an IRSA role + policy.<br/>      extra = optional(map(object({<br/>        name                   = string<br/>        namespace              = optional(string, null) # defaults to k8s.default_namespace<br/>        iam_role_name_override = optional(string, null) # overrides computed "<key>-<partner_name>-<environment>"<br/>        s3_bucket_access = optional(map(object({<br/>          actions = list(string)<br/>        })), {})<br/>        rds_master_secret_access = optional(bool, false)<br/>        iam_policy_statements = optional(list(object({<br/>          sid       = optional(string, "")<br/>          effect    = string<br/>          actions   = list(string)<br/>          resources = list(string)<br/>          conditions = optional(list(object({<br/>            test     = string<br/>            variable = string<br/>            values   = list(string)<br/>          })), [])<br/>        })), [])<br/>        labels      = optional(map(string), {})<br/>        annotations = optional(map(string), {})<br/>      })), {})<br/>    }), {})<br/><br/>    # Storage classes — built-in toggles + custom extras.<br/>    storage_classes = optional(object({<br/>      # gp3: encrypted EBS gp3, WaitForFirstConsumer, set as cluster default.<br/>      gp3 = optional(object({<br/>        enabled = optional(bool, true)<br/>      }), {})<br/><br/>      # Custom storage classes beyond the built-ins.<br/>      # An entry with the same key as a built-in overrides it entirely.<br/>      extra = optional(map(object({<br/>        provisioner            = string<br/>        reclaim_policy         = optional(string, "Delete")<br/>        volume_binding_mode    = optional(string, "WaitForFirstConsumer")<br/>        allow_volume_expansion = optional(bool, true)<br/>        parameters             = optional(map(string), {})<br/>        annotations            = optional(map(string), {})<br/>        labels                 = optional(map(string), {})<br/>      })), {})<br/>    }), {})<br/><br/>    # ExternalName services — map key becomes the Service name.<br/>    # Endpoints resolved by the root module; port is stripped automatically.<br/>    external_name_services = optional(map(object({<br/>      enabled     = optional(bool, true)<br/>      endpoint    = optional(string, null) # host:port or bare hostname<br/>      namespace   = optional(string, null) # defaults to k8s.default_namespace<br/>      annotations = optional(map(string), {})<br/>    })), {})<br/>  })</pre> | <pre>{<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | ARN of the EKS cluster OIDC provider, used to build IRSA trust policies. | `string` | n/a | yes |
| <a name="input_partner_name"></a> [partner\_name](#input\_partner\_name) | Partner identifier, used for IAM resource naming. | `string` | n/a | yes |
| <a name="input_rds_master_secret_arn"></a> [rds\_master\_secret\_arn](#input\_rds\_master\_secret\_arn) | ARN of the Secrets Manager secret containing the RDS master user password. Required when any service account sets rds\_master\_secret\_access = true. | `string` | `null` | no |
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
