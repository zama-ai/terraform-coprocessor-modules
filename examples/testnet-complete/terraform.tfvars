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
        enabled             = true
        acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" # CHANGE ME: ACM cert ARN (must be in us-east-1)
        aliases             = ["assets.example.com"]                                                                # CHANGE ME: your CloudFront custom hostname(s)
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
      values     = <<-YAML
        image:
          repository: hub.zama.org/zama-protocol/zama.ai/metrics-server
          tag: v0.8.0
        imagePullSecrets:
          - name: registry-credentials
      YAML
    }

    karpenter = {
      enabled    = true
      repository = "oci://public.ecr.aws/karpenter"
      chart      = "karpenter"
      version    = "1.11.0"
      values     = <<-YAML
        controller:
          image:
            repository: hub.zama.org/zama-protocol/zama.ai/karpenter
            tag: v1.11.0
        imagePullSecrets:
          - name: registry-credentials
      YAML
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
      values     = <<-YAML
        image:
          repository: hub.zama.org/cgr/zama.ai/postgres-exporter
          tag: v0.18.1
        imagePullSecrets:
          - name: registry-credentials
      YAML
    }

    k8s_monitoring = {
      enabled    = true
      repository = "https://grafana.github.io/helm-charts"
      chart      = "k8s-monitoring"
      version    = "4.0.1"

      prometheus_url = "https://prometheus-prod-XX-eu-west-0.grafana.net/api/prom/push" # CHANGE ME
      loki_url       = "https://logs-prod-eu-west-0.grafana.net/loki/api/v1/push"       # CHANGE ME
      otlp_url       = "https://otlp-gateway-prod-eu-west-0.grafana.net/otlp"           # CHANGE ME

      values = <<-YAML
        alloy-operator:
          image:
            registry: hub.zama.org
            repository: zama-protocol/zama.ai/grafana-alloy-operator
            tag: v0.5.3
          imagePullSecrets:
            - name: registry-credentials

        collectors:
          alloy-metrics:
            image:
              registry: hub.zama.org
              repository: zama-protocol/zama.ai/grafana-alloy
              tag: 1.15.0
              pullSecrets:
                - registry-credentials
          alloy-logs:
            image:
              registry: hub.zama.org
              repository: zama-protocol/zama.ai/grafana-alloy
              tag: 1.15.0
              pullSecrets:
                - registry-credentials
          alloy-receiver:
            image:
              registry: hub.zama.org
              repository: zama-protocol/zama.ai/grafana-alloy
              tag: 1.15.0
              pullSecrets:
                - registry-credentials
      YAML
    }
  }
}
