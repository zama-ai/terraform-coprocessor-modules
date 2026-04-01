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
#  k8s
# =============================================================================
k8s = {
  enabled           = true
  default_namespace = "coproc"

  namespaces = {
    coproc = {
      labels = {
        "app.kubernetes.io/name"       = "coprocessor"
        "app.kubernetes.io/component"  = "storage"
        "app.kubernetes.io/part-of"    = "zama-protocol"
        "app.kubernetes.io/managed-by" = "terraform"
      }
      annotations = {
        "terraform.io/module" = "coprocessor"
      }
    }
  }

  service_accounts = {
    coprocessor = {
      name      = "coprocessor"
      namespace = "coproc"
      s3_bucket_access = {
        coprocessor = { actions = ["s3:*Object", "s3:ListBucket"] }
      }
    }
  }

  storage_classes = {
    gp3 = {
      provisioner         = "ebs.csi.aws.com"
      reclaim_policy      = "Delete"
      volume_binding_mode = "WaitForFirstConsumer"
      parameters = {
        type      = "gp3"
        fsType    = "ext4"
        encrypted = "true"
      }
      annotations = {
        "storageclass.kubernetes.io/is-default-class" = "true"
      }
    }
  }

  external_name_services = {
    coprocessor-database = {
      # endpoint omitted — injected automatically from the rds submodule
      namespace = "coproc"
    }
  }
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
