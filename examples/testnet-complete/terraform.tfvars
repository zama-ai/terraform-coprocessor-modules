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
      preconfigured_bucket_access_profile = "public"

      cloudfront = {
        enabled             = true
        acm_certificate_arn = ""   # CHANGE ME: ACM cert ARN (must be in us-east-1)
        aliases             = [""] # CHANGE ME: your CloudFront custom hostname(s)
      }
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
    karpenter      = { enabled = true }
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
    karpenter_nodepools = { enabled = false } # CHANGE ME: refer to operator documentation regarding order of deployments

    prometheus_operator_crds = {
      enabled    = true
      repository = "https://prometheus-community.github.io/helm-charts"
      chart      = "prometheus-operator-crds"
      version    = "28.0.1"
    }

    metrics_server = {
      enabled    = true
      repository = "https://kubernetes-sigs.github.io/metrics-server"
      chart      = "metrics-server"
      version    = "3.13.0"
      image_tag  = "v0.8.0"
    }

    karpenter = {
      enabled              = true
      repository           = "oci://public.ecr.aws/karpenter"
      chart                = "karpenter"
      version              = "1.10.0"
      controller_image_tag = "v1.11.0"
    }

    prometheus_rds_exporter = {
      enabled    = true
      repository = "oci://public.ecr.aws/qonto"
      chart      = "prometheus-rds-exporter-chart"
      version    = "0.16.0"
    }

    prometheus_postgres_exporter = {
      enabled    = true
      repository = "https://prometheus-community.github.io/helm-charts"
      chart      = "prometheus-postgres-exporter"
      version    = "7.3.0"
      image_tag  = "v0.19.1"
    }

    k8s_monitoring = {
      enabled    = true
      repository = "https://grafana.github.io/helm-charts"
      chart      = "k8s-monitoring"
      version    = "4.0.1"

      prometheus_url = "" # CHANGE ME
      loki_url       = "" # CHANGE ME
      otlp_url       = "" # CHANGE ME
    }
  }
}
