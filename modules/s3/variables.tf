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
      purpose = optional(string, "coprocessor-storage")

      # Override the computed bucket name (use when importing a pre-existing bucket)
      name_override = optional(string, null)

      # Allow deletion even if objects exist
      force_destroy = optional(bool, false)

      # Enable object versioning
      versioning = optional(bool, true)

      # Preconfigured bundle of public_access + cors + policy_statements.
      # When set, these three fields MUST be left unset. Allowed values:
      #   - "public": bucket is publicly readable, CORS open, with PublicRead + ZamaList policy statements.
      preconfigured_bucket_access_profile = optional(string, null)

      # Public access configuration. Leave unset when preconfigured_bucket_access_profile is set.
      public_access = optional(object({
        enabled = bool
      }), null)

      # CORS configuration. Leave unset when preconfigured_bucket_access_profile is set.
      cors = optional(object({
        enabled         = bool
        allowed_origins = list(string)
        allowed_methods = list(string)
        allowed_headers = list(string)
        expose_headers  = list(string)
      }), null)

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
        aliases                   = optional(list(string), [])       # custom hostnames (CNAMEs) for the distribution; requires acm_certificate_arn
        acm_certificate_arn       = optional(string, null)           # if set, used instead of default CloudFront certificate
        ssl_support_method        = optional(string, "sni-only")     # only relevant when acm_certificate_arn is set
        minimum_protocol_version  = optional(string, "TLSv1.2_2021") # only relevant when acm_certificate_arn is set
      }), { enabled = false })

      # Bucket policies. Leave unset when preconfigured_bucket_access_profile is set.
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
      })), null)
    })
  )

  validation {
    condition = alltrue([
      for k, v in var.buckets :
      v.preconfigured_bucket_access_profile == null
      || contains(["public"], v.preconfigured_bucket_access_profile)
    ])
    error_message = "preconfigured_bucket_access_profile must be one of: \"public\" (or null/unset)."
  }

  validation {
    condition = alltrue([
      for k, v in var.buckets :
      v.preconfigured_bucket_access_profile == null
      || (v.public_access == null && v.cors == null && v.policy_statements == null)
    ])
    error_message = "When preconfigured_bucket_access_profile is set, public_access, cors, and policy_statements must be left unset. Use either the profile or explicit fields, not both."
  }
}
