mock_provider "aws" {}

# Shared defaults across all runs — individual runs may override.
variables {
  partner_name = "acme"
  environment  = "mainnet"
}

# =============================================================================
#  Bucket naming
# =============================================================================

run "name_override_sets_bucket_argument" {
  command = plan

  variables {
    buckets = {
      coprocessor = {
        purpose       = "test"
        name_override = "my-existing-bucket"
      }
    }
  }

  assert {
    condition     = aws_s3_bucket.this["coprocessor"].bucket == "my-existing-bucket"
    error_message = "name_override must be passed as the bucket argument."
  }
}

# =============================================================================
#  Versioning
# =============================================================================

run "versioning_enabled_by_default" {
  command = plan

  variables {
    buckets = {
      coprocessor = { purpose = "test" }
    }
  }

  assert {
    condition     = aws_s3_bucket_versioning.this["coprocessor"].versioning_configuration[0].status == "Enabled"
    error_message = "Versioning must be Enabled by default."
  }
}

# =============================================================================
#  Public access
# =============================================================================

run "public_access_blocked_by_default" {
  command = plan

  variables {
    buckets = {
      coprocessor = { purpose = "test" }
    }
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this["coprocessor"].block_public_acls == true
    error_message = "block_public_acls must be true by default."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this["coprocessor"].ignore_public_acls == true
    error_message = "ignore_public_acls must be true by default."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this["coprocessor"].block_public_policy == true
    error_message = "block_public_policy must be true by default."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this["coprocessor"].restrict_public_buckets == true
    error_message = "restrict_public_buckets must be true by default."
  }
}

# =============================================================================
#  Ownership controls
# =============================================================================

run "ownership_enforced_on_all_buckets" {
  command = plan

  variables {
    buckets = {
      coprocessor = { purpose = "test" }
    }
  }

  assert {
    condition     = aws_s3_bucket_ownership_controls.this["coprocessor"].rule[0].object_ownership == "BucketOwnerEnforced"
    error_message = "All buckets must have BucketOwnerEnforced ownership controls."
  }
}

# =============================================================================
#  CORS
# =============================================================================

run "cors_created_when_enabled" {
  command = plan

  variables {
    buckets = {
      coprocessor = {
        purpose = "test"
        cors = {
          enabled         = true
          allowed_origins = ["https://example.com"]
          allowed_methods = ["GET", "HEAD"]
          allowed_headers = ["Authorization"]
          expose_headers  = ["ETag"]
        }
      }
    }
  }

  assert {
    condition     = length(aws_s3_bucket_cors_configuration.this) == 1
    error_message = "A CORS resource must be created when cors.enabled = true."
  }

  assert {
    condition     = one([for r in aws_s3_bucket_cors_configuration.this["coprocessor"].cors_rule : r]).allowed_origins == toset(["https://example.com"])
    error_message = "CORS allowed_origins must match the configured value."
  }

  assert {
    condition     = one([for r in aws_s3_bucket_cors_configuration.this["coprocessor"].cors_rule : r]).allowed_methods == toset(["GET", "HEAD"])
    error_message = "CORS allowed_methods must match the configured value."
  }
}

run "cors_only_created_for_buckets_that_enable_it" {
  command = plan

  variables {
    buckets = {
      public = {
        purpose = "test"
        cors = {
          enabled         = true
          allowed_origins = ["*"]
          allowed_methods = ["GET"]
          allowed_headers = ["*"]
          expose_headers  = []
        }
      }
      private = { purpose = "test" }
    }
  }

  assert {
    condition     = length(aws_s3_bucket_cors_configuration.this) == 1
    error_message = "CORS resource must only be created for buckets where cors.enabled = true."
  }

  assert {
    condition     = contains(keys(aws_s3_bucket_cors_configuration.this), "public")
    error_message = "CORS resource must exist for the 'public' bucket."
  }
}

# =============================================================================
#  Bucket policy
# =============================================================================

run "bucket_policy_created_with_statements" {
  command = plan

  variables {
    buckets = {
      coprocessor = {
        purpose = "test"
        policy_statements = [
          {
            sid        = "PublicRead"
            effect     = "Allow"
            principals = { "*" = [] }
            actions    = ["s3:GetObject"]
            resources  = ["objects"]
          }
        ]
      }
    }
  }

  assert {
    condition     = length(aws_s3_bucket_policy.this) == 1
    error_message = "A bucket policy must be created when policy_statements is non-empty."
  }
}

# =============================================================================
#  Multiple buckets
# =============================================================================

run "multiple_buckets_produce_separate_resources" {
  command = plan

  variables {
    buckets = {
      alpha = { purpose = "test-a" }
      beta  = { purpose = "test-b" }
      gamma = { purpose = "test-c" }
    }
  }

  assert {
    condition     = length(aws_s3_bucket.this) == 3
    error_message = "Each bucket key must produce a separate aws_s3_bucket resource."
  }

  assert {
    condition     = length(aws_s3_bucket_versioning.this) == 3
    error_message = "Each bucket must have a versioning resource."
  }

  assert {
    condition     = length(aws_s3_bucket_public_access_block.this) == 3
    error_message = "Each bucket must have a public access block resource."
  }

  assert {
    condition     = length(aws_s3_bucket_ownership_controls.this) == 3
    error_message = "Each bucket must have an ownership controls resource."
  }
}

# =============================================================================
#  CloudFront
# =============================================================================

# Absorbs default-certificate and empty-aliases assertions (previously separate tests).
run "cloudfront_created_when_enabled" {
  command = plan

  variables {
    buckets = {
      coprocessor = {
        purpose    = "test"
        cloudfront = { enabled = true }
      }
    }
  }

  assert {
    condition     = length(aws_cloudfront_distribution.this) == 1
    error_message = "A CloudFront distribution must be created when cloudfront.enabled = true."
  }

  assert {
    condition     = contains(keys(aws_cloudfront_distribution.this), "coprocessor")
    error_message = "CloudFront distribution key must match the bucket key."
  }

  assert {
    condition     = aws_cloudfront_distribution.this["coprocessor"].viewer_certificate[0].cloudfront_default_certificate == true
    error_message = "CloudFront must use the default certificate when no acm_certificate_arn is set."
  }

  assert {
    condition     = length(aws_cloudfront_distribution.this["coprocessor"].aliases) == 0
    error_message = "CloudFront aliases must be empty when none are configured."
  }
}

run "cloudfront_uses_acm_certificate_when_provided" {
  command = plan

  variables {
    buckets = {
      coprocessor = {
        purpose = "test"
        cloudfront = {
          enabled             = true
          aliases             = ["assets.example.com"]
          acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/abc-12345"
        }
      }
    }
  }

  assert {
    condition     = aws_cloudfront_distribution.this["coprocessor"].viewer_certificate[0].cloudfront_default_certificate == false
    error_message = "CloudFront must not use the default certificate when acm_certificate_arn is set."
  }

  assert {
    condition     = aws_cloudfront_distribution.this["coprocessor"].viewer_certificate[0].acm_certificate_arn == "arn:aws:acm:us-east-1:123456789012:certificate/abc-12345"
    error_message = "CloudFront must use the provided ACM certificate ARN."
  }
}

# =============================================================================
#  preconfigured_bucket_access_profile
# =============================================================================

run "profile_public_applies_full_bundle_and_does_not_leak" {
  command = plan

  variables {
    buckets = {
      coprocessor = { preconfigured_bucket_access_profile = "public" }
      private     = {}
    }
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this["coprocessor"].block_public_acls == false
    error_message = "Profile 'public' must unblock public ACLs on the profiled bucket."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this["private"].block_public_acls == true
    error_message = "Sibling buckets without a profile must remain fully blocked."
  }

  assert {
    condition     = length(aws_s3_bucket_cors_configuration.this) == 1 && length(aws_s3_bucket_policy.this) == 1
    error_message = "CORS and policy must be created only for the profiled bucket."
  }

  assert {
    condition     = one([for r in aws_s3_bucket_cors_configuration.this["coprocessor"].cors_rule : r]).allowed_origins == toset(["*"])
    error_message = "Profile 'public' CORS must allow origin '*'."
  }
}

run "profile_rejects_unknown_value" {
  command = plan

  variables {
    buckets = {
      coprocessor = { preconfigured_bucket_access_profile = "totally-made-up" }
    }
  }

  expect_failures = [var.buckets]
}

run "profile_rejects_mix_with_explicit_fields" {
  command = plan

  variables {
    buckets = {
      coprocessor = {
        preconfigured_bucket_access_profile = "public"
        public_access                       = { enabled = true }
        cors = {
          enabled         = true
          allowed_origins = ["https://example.com"]
          allowed_methods = ["GET"]
          allowed_headers = []
          expose_headers  = []
        }
        policy_statements = [{
          sid        = "Custom"
          effect     = "Allow"
          principals = { "*" = ["*"] }
          actions    = ["s3:GetObject"]
          resources  = ["objects"]
        }]
      }
    }
  }

  expect_failures = [var.buckets]
}
