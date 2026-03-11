# ==============================================================================
# PLEASE NOTE the variables provided below, in conjunction with module defaults,
# make for a complete deployment.
#
# For additional info on available parameters, see root module variables.tf for
# full variable schema.
# ==============================================================================

# =============================================================================
#  Core
# =============================================================================
partner_name = "acme" # CHANGE ME: lowercase, used as a prefix in resource names
environment  = "devnet"
aws_region   = "eu-west-1" # CHANGE ME: AWS region to deploy into

default_tags = {
  Partner     = "acme" # CHANGE ME: match partner_name
  Environment = "devnet"
  ManagedBy   = "terraform"
}

# =============================================================================
#  Networking — existing VPC, no new networking resources created
# =============================================================================
networking = {
  enabled = false

  existing_vpc = {
    vpc_id                     = "vpc-0123456789abcdef0"        # CHANGE ME
    private_subnet_ids         = ["subnet-aaa", "subnet-bbb"]   # CHANGE ME
    private_subnet_cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24"] # CHANGE ME
  }
}

# =============================================================================
#  EKS — disabled, using existing cluster
# =============================================================================
eks = {
  enabled = false
}

# =============================================================================
#  RDS (PostgreSQL)
# =============================================================================
rds = {
  enabled  = true
  db_name  = "coprocessor"
  username = "coprocessor"

  # Password is managed by AWS Secrets Manager by default (recommended).
  # Rotation is enabled automatically every 7 days.
  # To use a static password instead:
  #   manage_master_user_password = false
  #   password_wo                 = "your-password"   # write-only, not stored in state
  #   enable_master_password_rotation = false
}

# =============================================================================
#  S3
# =============================================================================
s3 = {
  buckets = {
    coprocessor = {
      purpose       = "coprocessor-storage"
      force_destroy = true

      public_access = {
        enabled = true
      }

      cors = {
        enabled         = true
        allowed_origins = ["*"]
        allowed_methods = ["GET", "HEAD"]
        allowed_headers = ["Authorization"]
        expose_headers  = ["Access-Control-Allow-Origin"]
      }

      policy_statements = [
        {
          sid        = "PublicRead"
          effect     = "Allow"
          principals = { "*" = ["*"] }
          actions    = ["s3:GetObject"]
          resources  = ["objects"]
        },
        {
          sid        = "ZamaList"
          effect     = "Allow"
          principals = { "*" = ["*"] }
          actions    = ["s3:ListBucket"]
          resources  = ["bucket"]
        }
      ]
    }
  }
}
