variable "partner_name" {
  description = "Partner identifier, used for resource naming and tagging."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. devnet, mainnet, testnet)."
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