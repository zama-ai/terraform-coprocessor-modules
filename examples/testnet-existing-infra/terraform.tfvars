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
#  Kubernetes Provider — required when eks.enabled = false
# =============================================================================
kubernetes_provider = {
  host                   = "https://XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX.gr7.eu-west-1.eks.amazonaws.com"                                     # CHANGE ME
  cluster_ca_certificate = "LS0tLS1CRUdJTi..."                                                                                            # CHANGE ME: base64-encoded CA cert from your cluster
  cluster_name           = "acme-testnet"                                                                                                 # CHANGE ME: your existing cluster name
  oidc_provider_arn      = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E" # CHANGE ME
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
#  k8s Charts — not managed here
#
#  Partners using an existing cluster are expected to operate their own
#  system-level Helm releases. This module does not deploy:
#    - metrics-server  (assumed present in the existing cluster)
#    - karpenter       (assumed present; IAM/SQS resources are partner-managed)
#
#  To adopt these releases into Terraform management, set k8s_charts.enabled = true
#  and add the relevant application entries (see testnet-complete for reference).
# =============================================================================

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
