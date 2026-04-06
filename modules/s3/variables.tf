variable "partner_name" {
  description = "Partner identifier, used for resource naming and tagging."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. testnet, mainnet)."
  type        = string
}

variable "buckets" {
  description = <<-EOT
    Map of S3 buckets to create.

    The map key is a short logical name (e.g. "coprocessor", "raw-data").
    Each entry defines configuration and behavior for that bucket.
  EOT

  type = map(
    object({
      # Human-readable description (used for tagging)
      purpose = string

      # Override the computed bucket name (use when importing a pre-existing bucket)
      name_override = optional(string, null)

      # Allow deletion even if objects exist
      force_destroy = optional(bool, false)

      # Enable object versioning
      versioning = optional(bool, true)

      # Public access configuration
      public_access = optional(object({
        enabled = bool
        }), {
        enabled = false
      })

      # CORS configuration
      cors = optional(object({
        enabled         = bool
        allowed_origins = list(string)
        allowed_methods = list(string)
        allowed_headers = list(string)
        expose_headers  = list(string)
        }), {
        enabled         = false
        allowed_origins = []
        allowed_methods = []
        allowed_headers = []
        expose_headers  = []
      })

      # CloudFront distribution
      cloudfront = optional(object({
        enabled                   = optional(bool, false)
        price_class               = optional(string, "PriceClass_All")
        compress                  = optional(bool, true)
        viewer_protocol_policy    = optional(string, "redirect-to-https")
        allowed_methods           = optional(list(string), ["GET", "HEAD"])
        cached_methods            = optional(list(string), ["GET", "HEAD"])
        cache_policy_id           = optional(string, "658327ea-f89d-4fab-a63d-7e88639e58f6") # AWS managed CachingOptimized
        geo_restriction_type      = optional(string, "none")
        geo_restriction_locations = optional(list(string), [])
        acm_certificate_arn       = optional(string, null)           # if set, used instead of default CloudFront certificate
        ssl_support_method        = optional(string, "sni-only")     # only relevant when acm_certificate_arn is set
        minimum_protocol_version  = optional(string, "TLSv1.2_2021") # only relevant when acm_certificate_arn is set
      }), { enabled = false })

      # Bucket policies
      policy_statements = optional(list(object({
        sid        = string
        effect     = string
        principals = map(list(string))
        actions    = list(string)
        resources  = list(string)
        conditions = optional(list(object({
          test     = string
          variable = string
          values   = list(string)
        })), [])
      })), [])
    })
  )
}
