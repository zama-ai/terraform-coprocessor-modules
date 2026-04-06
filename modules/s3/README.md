<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11 |
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
| [aws_cloudfront_distribution.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution) | resource |
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
| <a name="input_buckets"></a> [buckets](#input\_buckets) | Map of S3 buckets to create.<br/><br/>The map key is a short logical name (e.g. "coprocessor", "raw-data").<br/>Each entry defines configuration and behavior for that bucket. | <pre>map(<br/>    object({<br/>      # Human-readable description (used for tagging)<br/>      purpose = string<br/><br/>      # Override the computed bucket name (use when importing a pre-existing bucket)<br/>      name_override = optional(string, null)<br/><br/>      # Allow deletion even if objects exist<br/>      force_destroy = optional(bool, false)<br/><br/>      # Enable object versioning<br/>      versioning = optional(bool, true)<br/><br/>      # Public access configuration<br/>      public_access = optional(object({<br/>        enabled = bool<br/>        }), {<br/>        enabled = false<br/>      })<br/><br/>      # CORS configuration<br/>      cors = optional(object({<br/>        enabled         = bool<br/>        allowed_origins = list(string)<br/>        allowed_methods = list(string)<br/>        allowed_headers = list(string)<br/>        expose_headers  = list(string)<br/>        }), {<br/>        enabled         = false<br/>        allowed_origins = []<br/>        allowed_methods = []<br/>        allowed_headers = []<br/>        expose_headers  = []<br/>      })<br/><br/>      # CloudFront distribution<br/>      cloudfront = optional(object({<br/>        enabled                   = optional(bool, false)<br/>        price_class               = optional(string, "PriceClass_All")<br/>        compress                  = optional(bool, true)<br/>        viewer_protocol_policy    = optional(string, "redirect-to-https")<br/>        allowed_methods           = optional(list(string), ["GET", "HEAD"])<br/>        cached_methods            = optional(list(string), ["GET", "HEAD"])<br/>        cache_policy_id           = optional(string, "658327ea-f89d-4fab-a63d-7e88639e58f6") # AWS managed CachingOptimized<br/>        geo_restriction_type      = optional(string, "none")<br/>        geo_restriction_locations = optional(list(string), [])<br/>        acm_certificate_arn       = optional(string, null)           # if set, used instead of default CloudFront certificate<br/>        ssl_support_method        = optional(string, "sni-only")     # only relevant when acm_certificate_arn is set<br/>        minimum_protocol_version  = optional(string, "TLSv1.2_2021") # only relevant when acm_certificate_arn is set<br/>      }), { enabled = false })<br/><br/>      # Bucket policies<br/>      policy_statements = optional(list(object({<br/>        sid        = string<br/>        effect     = string<br/>        principals = map(list(string))<br/>        actions    = list(string)<br/>        resources  = list(string)<br/>        conditions = optional(list(object({<br/>          test     = string<br/>          variable = string<br/>          values   = list(string)<br/>        })), [])<br/>      })), [])<br/>    })<br/>  )</pre> | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (e.g. testnet, mainnet). | `string` | n/a | yes |
| <a name="input_partner_name"></a> [partner\_name](#input\_partner\_name) | Partner identifier, used for resource naming and tagging. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_arns"></a> [bucket\_arns](#output\_bucket\_arns) | Map of logical bucket key to bucket ARN. |
| <a name="output_bucket_names"></a> [bucket\_names](#output\_bucket\_names) | Map of logical bucket key to bucket name. |
| <a name="output_cloudfront_distribution_ids"></a> [cloudfront\_distribution\_ids](#output\_cloudfront\_distribution\_ids) | Map of logical bucket key to CloudFront distribution ID. Empty for buckets without CloudFront enabled. |
| <a name="output_cloudfront_domain_names"></a> [cloudfront\_domain\_names](#output\_cloudfront\_domain\_names) | Map of logical bucket key to CloudFront distribution domain name. Empty for buckets without CloudFront enabled. |
<!-- END_TF_DOCS -->
