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
environment  = "testnet"
aws_region   = "eu-west-1" # CHANGE ME: AWS region to deploy into

default_tags = {
  Partner     = "acme" # CHANGE ME: match partner_name
  Environment = "testnet"
  ManagedBy   = "terraform"
}

# =============================================================================
#  Networking
# =============================================================================
networking = {
  enabled = true

  vpc = {
    cidr               = "10.1.0.0/16"                              # CHANGE ME: must not overlap with existing VPCs
    availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"] # CHANGE ME: match aws_region
    single_nat_gateway = true
  }
}

# =============================================================================
#  EKS
# =============================================================================
eks = {
  enabled = true

  cluster = {
    # Private-only by default — restrict endpoint_public_access_cidrs to your office / VPN IP range.
    endpoint_public_access       = true
    endpoint_public_access_cidrs = ["x.x.x.x/32"] # CHANGE ME: restrict to known IPs
  }

  node_groups = {
    groups = {
      default = {
        instance_types = ["t3.large"]
      }
    }
  }

  karpenter = {
    enabled          = true
    rule_name_prefix = "coproc"

    controller_nodegroup = {
      enabled        = true
      instance_types = ["t3.small"]
    }
  }
}

# =============================================================================
#  RDS (PostgreSQL)
# =============================================================================
rds = {
  enabled  = true
  db_name  = "coprocessor"
  username = "coprocessor"
}

# =============================================================================
#  S3
# =============================================================================
s3 = {
  buckets = {
    coprocessor = {
      purpose = "coprocessor-storage"

      public_access = {
        enabled = true
      }

      cloudfront = {
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

# =============================================================================
#  k8s Coprocessor Dependencies
# =============================================================================
k8s_coprocessor_deps = {
  enabled = true

  namespaces = {
    coproc         = { enabled = true }
    coproc-admin   = { enabled = true }
    monitoring     = { enabled = true }
    gw-blockchain  = { enabled = true }
    eth-blockchain = { enabled = true }
  }

  service_accounts = {
    coprocessor = { enabled = true }
    db_admin    = { enabled = true }
  }

  storage_classes = {
    gp3 = { enabled = true }
  }

  external_name_services = {
    coprocessor-database = { enabled = true }
  }
}

# =============================================================================
#  k8s System Charts
# =============================================================================
k8s_system_charts = {
  enabled = false # CHANGE ME: refer to operator documentation regarding order of deployments

  defaults = {
    karpenter_nodepools          = { enabled = false } # CHANGE ME: refer to operator documentation regarding order of deployments
    prometheus_operator_crds     = { enabled = true }
    metrics_server               = { enabled = true }
    karpenter                    = { enabled = true }
    prometheus_rds_exporter      = { enabled = true }
    prometheus_postgres_exporter = { enabled = true }

    k8s_monitoring = {
      enabled = true

      prometheus_url = "" # CHANGE ME
      loki_url       = "" # CHANGE ME
      otlp_url       = "" # CHANGE ME
    }
  }
}
