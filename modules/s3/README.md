<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_cors_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_cors_configuration) | resource |
| [aws_s3_bucket_ownership_controls.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [aws_iam_policy_document.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_buckets"></a> [buckets](#input\_buckets) | Map of S3 buckets to create.<br/><br/>The map key is a short logical name (e.g. "coprocessor", "raw-data").<br/>Each entry defines configuration and behavior for that bucket. | <pre>map(<br/>    object({<br/>      # Human-readable description (used for tagging)<br/>      purpose = string<br/><br/>      # Override the computed bucket name (use when importing a pre-existing bucket)<br/>      name_override = optional(string, null)<br/><br/>      # Allow deletion even if objects exist<br/>      force_destroy = optional(bool, false)<br/><br/>      # Enable object versioning<br/>      versioning = optional(bool, true)<br/><br/>      # Public access configuration<br/>      public_access = optional(object({<br/>        enabled = bool<br/>        }), {<br/>        enabled = false<br/>      })<br/><br/>      # CORS configuration<br/>      cors = optional(object({<br/>        enabled         = bool<br/>        allowed_origins = list(string)<br/>        allowed_methods = list(string)<br/>        allowed_headers = list(string)<br/>        expose_headers  = list(string)<br/>        }), {<br/>        enabled         = false<br/>        allowed_origins = []<br/>        allowed_methods = []<br/>        allowed_headers = []<br/>        expose_headers  = []<br/>      })<br/><br/>      # Bucket policies<br/>      policy_statements = optional(list(object({<br/>        sid        = string<br/>        effect     = string<br/>        principals = map(list(string))<br/>        actions    = list(string)<br/>        resources  = list(string)<br/>        conditions = optional(list(object({<br/>          test     = string<br/>          variable = string<br/>          values   = list(string)<br/>        })), [])<br/>      })), [])<br/>    })<br/>  )</pre> | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (e.g. devnet, mainnet, testnet). | `string` | n/a | yes |
| <a name="input_partner_name"></a> [partner\_name](#input\_partner\_name) | Partner identifier, used for resource naming and tagging. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_arns"></a> [bucket\_arns](#output\_bucket\_arns) | Map of logical bucket key to bucket ARN. |
| <a name="output_bucket_names"></a> [bucket\_names](#output\_bucket\_names) | Map of logical bucket key to bucket name. |
<!-- END_TF_DOCS -->
