variable "partner_name" {
  description = "Partner identifier, used for resource naming and tagging."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. prod, staging)."
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "buckets" {
  description = <<-EOT
    Map of S3 buckets to create.

    The map key is a short logical name (e.g. "coprocessor", "raw-data").
    Each entry defines configuration and behavior for that bucket.
  EOT

  type = map(object({
    # Human-readable description (used for tagging)
    purpose = string

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
  }))
}