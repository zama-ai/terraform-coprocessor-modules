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
  host                   = "https://XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX.gr7.eu-west-1.eks.amazonaws.com"                                     # CHANGE ME: your EKS cluster API endpoint
  cluster_ca_certificate = "LS0tLS1CRUdJTi..."                                                                                            # CHANGE ME: base64-encoded CA cert from your cluster
  cluster_name           = "acme-testnet"                                                                                                 # CHANGE ME: your existing cluster name
  oidc_provider_arn      = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E" # CHANGE ME: your OIDC provider ARN
}

# =============================================================================
#  Networking — existing VPC, no new networking resources created
# =============================================================================
networking = {
  enabled = false

  existing_vpc = {
    vpc_id             = "vpc-0123456789abcdef0"      # CHANGE ME
    private_subnet_ids = ["subnet-aaa", "subnet-bbb"] # CHANGE ME
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
      preconfigured_bucket_access_profile = "public"

      cloudfront = {
        enabled             = true
        acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" # CHANGE ME: ACM cert ARN (must be in us-east-1)
        aliases             = ["assets.example.com"]                                                                # CHANGE ME: your CloudFront custom hostname(s)
      }
    }
  }
}


# =============================================================================
#  k8s Coprocessor Dependencies
# =============================================================================
k8s_coprocessor_deps = {
  enabled           = true
  default_namespace = "coproc"

  namespaces = {
    coproc         = { enabled = true }
    coproc-admin   = { enabled = true }
    gw-blockchain  = { enabled = true }
    eth-blockchain = { enabled = true }
    monitoring     = { enabled = true }
  }

  service_accounts = {
    sns_worker = { enabled = true }
    db_admin   = { enabled = true }
    tx_sender  = { enabled = true }
  }

  storage_classes = {
    gp3 = { enabled = true }
  }

  security_group_policies = {
    rds_client = { enabled = true }
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
#    - metrics-server                  (assumed present in the existing cluster)
#    - karpenter                       (assumed present; IAM/SQS resources are partner-managed)
#    - karpenter NodePool/EC2NodeClass (assumed present; see testnet-complete for reference)
#    - prometheus-operator-crds        (must be applied before any chart that creates ServiceMonitors)
#    - k8s-monitoring                  (requires grafana-cloud-credentials secret in monitoring namespace)
#    - prometheus-rds-exporter         (IRSA role created above via db-admin service account)
#    - prometheus-postgres-exporter    (requires postgres-exporter-config secret in monitoring namespace)
#
#  To adopt these releases into Terraform management, set k8s_charts.enabled = true
#  and add the relevant application entries (see testnet-complete for reference).
# =============================================================================
