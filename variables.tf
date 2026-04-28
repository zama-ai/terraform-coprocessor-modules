# ******************************************************
#  Core
# ******************************************************
variable "partner_name" {
  description = "Partner identifier — used as a name prefix across all resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. testnet, mainnet)."
  type        = string
}

variable "default_tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "aws_region" {
  description = "AWS region where resources will be deployed."
  type        = string
}

# ******************************************************
#  Kubernetes Provider
# ******************************************************
variable "kubernetes_provider" {
  description = "Kubernetes provider configuration. When eks.enabled = true these are resolved automatically from the EKS module. Set explicitly when bringing your own cluster."
  type = object({
    host                   = optional(string, null)
    cluster_ca_certificate = optional(string, null)
    cluster_name           = optional(string, null)
    oidc_provider_arn      = optional(string, null)
  })
  default = {}
}

# ******************************************************
#  Networking
# ******************************************************
variable "networking" {
  description = "VPC and subnet configuration. Set enabled = false to skip all networking resources."
  type = object({
    enabled = optional(bool, false)

    vpc = optional(object({
      # Base
      cidr               = string
      availability_zones = optional(list(string), []) # leave empty to auto-discover AZs
      single_nat_gateway = optional(bool, false)      # true = one NAT GW shared across AZs (cheaper, less resilient)

      # Subnet CIDR calculation
      private_subnet_cidr_mask = optional(number, 20)
      public_subnet_cidr_mask  = optional(number, 20)

      # Flow logs
      flow_log_enabled         = optional(bool, false)
      flow_log_destination_arn = optional(string, null)
    }), null)

    additional_subnets = optional(object({
      enabled   = optional(bool, false)
      cidr_mask = optional(number, 20)

      # EKS integration
      expose_for_eks = optional(bool, false)  # add karpenter.sh/discovery tag
      elb_role       = optional(string, null) # "internal" | "public" | null
      tags           = optional(map(string), {})
      node_groups    = optional(list(string), [])
    }), { enabled = false })

    # For usage of an existing VPC (bypasses networking module for RDS)
    existing_vpc = optional(object({
      vpc_id                     = string
      private_subnet_ids         = list(string)
      private_subnet_cidr_blocks = list(string)
    }))
  })

  validation {
    condition     = !var.networking.enabled || var.networking.vpc != null
    error_message = "networking.vpc is required when networking.enabled = true."
  }

  validation {
    condition     = var.networking.vpc == null || can(cidrhost(var.networking.vpc.cidr, 0))
    error_message = "networking.vpc.cidr must be a valid IPv4 CIDR block."
  }

  validation {
    condition = var.networking.enabled || (
      var.networking.existing_vpc != null &&
      length(var.networking.existing_vpc.private_subnet_ids) > 0 &&
      length(var.networking.existing_vpc.private_subnet_cidr_blocks) > 0
    )
    error_message = "networking.existing_vpc with non-empty private_subnet_ids and private_subnet_cidr_blocks is required when networking.enabled = false."
  }
}

# ******************************************************
#  EKS
# ******************************************************
variable "eks" {
  description = "EKS cluster configuration. Set enabled = false to skip all EKS resources."

  type = object({
    enabled = optional(bool, false)

    cluster = optional(object({
      # Naming
      version       = optional(string, "1.35")
      name_override = optional(string, null) # overrides computed "<name>-<env>" cluster name

      # Endpoint access
      endpoint_public_access       = optional(bool, false)
      endpoint_private_access      = optional(bool, true)
      endpoint_public_access_cidrs = optional(list(string), [])

      # Auth
      enable_irsa                      = optional(bool, true)
      enable_creator_admin_permissions = optional(bool, true) # grants the Terraform caller admin access
      admin_role_arns                  = optional(list(string), [])
    }), {})

    addons = optional(object({
      # Standard managed addons; each value is passed verbatim to the upstream eks module
      defaults = optional(map(any), {
        aws-ebs-csi-driver     = { most_recent = true }
        coredns                = { most_recent = true }
        vpc-cni                = { most_recent = true, before_compute = true }
        kube-proxy             = { most_recent = true }
        eks-pod-identity-agent = { most_recent = true, before_compute = true }
      })

      # Additional addons merged on top of defaults
      extra = optional(map(any), {})

      # VPC CNI environment tuning
      vpc_cni_config = optional(object({
        init = optional(object({
          env = optional(object({
            DISABLE_TCP_EARLY_DEMUX = optional(string, "true")
          }), {})
        }), {})
        env = optional(object({
          ENABLE_POD_ENI                    = optional(string, "true")
          POD_SECURITY_GROUP_ENFORCING_MODE = optional(string, "standard")
          ENABLE_PREFIX_DELEGATION          = optional(string, "true")
          WARM_PREFIX_TARGET                = optional(string, "1")
        }), {})
      }), {})
    }), {})

    node_groups = optional(object({
      # Defaults merged into every node group (same schema as groups entries)
      defaults = optional(map(any), {})

      # IAM policies attached to every node group's IAM role
      default_iam_policies = optional(map(string), {
        AmazonEBSCSIDriverPolicy           = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
        AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
        AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      })

      groups = optional(map(object({
        # Capacity
        capacity_type = optional(string, "ON_DEMAND") # "ON_DEMAND" | "SPOT"
        min_size      = optional(number, 1)
        max_size      = optional(number, 3)
        desired_size  = optional(number, 1)

        # Instance
        instance_types             = optional(list(string), ["t3.medium"])
        ami_type                   = optional(string, "AL2023_x86_64_STANDARD")
        use_custom_launch_template = optional(bool, true)

        # Storage
        disk_size = optional(number, 30)
        disk_type = optional(string, "gp3")

        # Scheduling
        labels                 = optional(map(string), {})
        tags                   = optional(map(string), {})
        use_additional_subnets = optional(bool, false) # place group in additional_subnet_ids instead of private
        taints = optional(map(object({
          key    = string
          value  = optional(string)
          effect = string # "NO_SCHEDULE" | "NO_EXECUTE" | "PREFER_NO_SCHEDULE"
        })), {})

        # Rolling updates (AWS requires exactly one of the two fields)
        update_config = optional(object({
          max_unavailable            = optional(number)
          max_unavailable_percentage = optional(number)
        }), { max_unavailable = 1 })

        # IAM
        iam_role_additional_policies = optional(map(string), {})

        # Instance metadata (IMDSv2 enforced by default; hop limit 1 blocks non-hostNetwork pods)
        metadata_options = optional(map(string), {
          http_endpoint               = "enabled"
          http_put_response_hop_limit = "1"
          http_tokens                 = "required"
        })
      })), {})
    }), {})

    karpenter = optional(object({
      enabled = optional(bool, true)

      # Controller identity
      namespace       = optional(string, "karpenter")
      service_account = optional(string, "karpenter")

      # SQS / EventBridge naming (defaults to computed values when null)
      queue_name       = optional(string, null)
      rule_name_prefix = optional(string, null) # max 20 chars

      # Node IAM
      create_spot_service_linked_role   = optional(bool, true)
      node_iam_role_additional_policies = optional(map(string), {})

      # Dedicated node group for the Karpenter controller pod
      controller_nodegroup = optional(object({
        enabled        = optional(bool, true)
        capacity_type  = optional(string, "ON_DEMAND")
        min_size       = optional(number, 1)
        max_size       = optional(number, 2)
        desired_size   = optional(number, 1)
        instance_types = optional(list(string), ["t3.small"])
        ami_type       = optional(string, "AL2023_x86_64_STANDARD")
        disk_size      = optional(number, 30)
        disk_type      = optional(string, "gp3")
        labels         = optional(map(string), { "karpenter.sh/controller" = "true" })
        taints = optional(map(object({
          key    = string
          value  = optional(string)
          effect = string
          })), {
          karpenter = {
            key    = "karpenter.sh/controller"
            value  = "true"
            effect = "NO_SCHEDULE"
          }
        })
      }), { enabled = true })
    }), { enabled = false })
  })

  default = { enabled = false }
}

# ******************************************************
#  RDS
# ******************************************************
variable "rds" {
  description = "RDS instance configuration. Set enabled = false to skip."

  type = object({
    enabled = optional(bool, false)

    # Naming
    db_name             = optional(string, null)
    identifier_override = optional(string, null)

    # Engine
    engine         = optional(string, "postgres")
    engine_version = optional(string, "17")

    # Instance
    instance_class        = optional(string, "db.m5.4xlarge")
    allocated_storage     = optional(number, 400)
    max_allocated_storage = optional(number, 1000)
    multi_az              = optional(bool, false)
    port                  = optional(number, 5432)

    # Credentials
    username                            = optional(string, "postgres")
    manage_master_user_password         = optional(bool, true)   # true = Secrets Manager managed (recommended)
    password_wo                         = optional(string, null) # write-only; only used when manage_master_user_password = false
    password_wo_version                 = optional(number, 1)    # increment to rotate a non-managed password
    enable_master_password_rotation     = optional(bool, true)
    master_password_rotation_days       = optional(number, 7)
    iam_database_authentication_enabled = optional(bool, true)

    # Maintenance & backups
    maintenance_window      = optional(string, "Mon:00:00-Mon:03:00")
    backup_retention_period = optional(number, 30)
    deletion_protection     = optional(bool, true)

    # Monitoring
    monitoring_interval          = optional(number, 60)
    create_monitoring_role       = optional(bool, true)
    monitoring_role_name         = optional(string, null)
    existing_monitoring_role_arn = optional(string, null)

    # Parameters
    parameters = optional(list(object({
      name  = string
      value = string
    })), [])

    # Security group
    additional_allowed_cidr_blocks = optional(list(string), [])
  })

  default = { enabled = true }
}

# ******************************************************
#  S3
# ******************************************************
variable "s3" {
  description = <<-EOT
    S3 configuration.

    - buckets: Map of S3 buckets to create.
      The map key is a short logical name (e.g. "coprocessor", "raw-data").
      Each entry defines configuration and behavior for that bucket.
  EOT

  type = object({
    buckets = map(object({
      # Human-readable description (used for tagging)
      purpose = optional(string, "coprocessor-storage")

      # Override the computed bucket name (use when importing a pre-existing bucket)
      name_override = optional(string, null)

      # Allow deletion even if objects exist
      force_destroy = optional(bool, false)

      # Enable object versioning
      versioning = optional(bool, true)

      # Preconfigured bundle of public_access + cors + policy_statements.
      # When set, these three fields MUST be left unset. Allowed values:
      #   - "public": bucket is publicly readable, CORS open, with PublicRead + ZamaList policy statements.
      preconfigured_bucket_access_profile = optional(string, null)

      # Public access configuration. Leave unset when preconfigured_bucket_access_profile is set.
      public_access = optional(object({
        enabled = bool
      }), null)

      # CORS configuration. Leave unset when preconfigured_bucket_access_profile is set.
      cors = optional(object({
        enabled         = bool
        allowed_origins = list(string)
        allowed_methods = list(string)
        allowed_headers = list(string)
        expose_headers  = list(string)
      }), null)

      # CloudFront distribution
      cloudfront = optional(object({
        enabled                   = optional(bool, false)
        price_class               = optional(string, "PriceClass_All")
        compress                  = optional(bool, true)
        viewer_protocol_policy    = optional(string, "redirect-to-https")
        allowed_methods           = optional(list(string), ["GET", "HEAD"])
        cached_methods            = optional(list(string), ["GET", "HEAD"])
        cache_policy_id           = optional(string, "658327ea-f89d-4fab-a63d-7e88639e58f6") # AWS managed CachingOptimized
        geo_restriction_type      = optional(string, "none")
        geo_restriction_locations = optional(list(string), [])
        aliases                   = optional(list(string), [])       # custom hostnames (CNAMEs) for the distribution; requires acm_certificate_arn
        acm_certificate_arn       = optional(string, null)           # if set, used instead of default CloudFront certificate
        ssl_support_method        = optional(string, "sni-only")     # only relevant when acm_certificate_arn is set
        minimum_protocol_version  = optional(string, "TLSv1.2_2021") # only relevant when acm_certificate_arn is set
      }), { enabled = false })

      # Bucket policies. Leave unset when preconfigured_bucket_access_profile is set.
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
      })), null)
    }))
  })

  default = { buckets = {} }

  validation {
    condition     = length(var.s3.buckets) > 0
    error_message = "s3.buckets must contain at least one bucket definition."
  }

  validation {
    condition = alltrue([
      for k, v in var.s3.buckets :
      v.preconfigured_bucket_access_profile == null
      || contains(["public"], v.preconfigured_bucket_access_profile)
    ])
    error_message = "preconfigured_bucket_access_profile must be one of: \"public\" (or null/unset)."
  }

  validation {
    condition = alltrue([
      for k, v in var.s3.buckets :
      v.preconfigured_bucket_access_profile == null
      || (v.public_access == null && v.cors == null && v.policy_statements == null)
    ])
    error_message = "When preconfigured_bucket_access_profile is set, public_access, cors, and policy_statements must be left unset. Use either the profile or explicit fields, not both."
  }
}

# ******************************************************
#  KMS
# ******************************************************
variable "kms" {
  description = <<-EOT
    Coprocessor KMS keypair configuration.

    Creates an asymmetric AWS KMS key (ECC_SECG_P256K1, SIGN_VERIFY) with
    EXTERNAL origin so an Ethereum secp256k1 private key can be imported,
    plus an alias `alias/<partner_name>-<environment>-coprocessor-keypair`.

    Cross-account deployments are handled out-of-band: invoke the kms
    submodule directly with an AWS provider configured for the target
    account. The root module always creates the key in the same account
    as the rest of the infrastructure.
  EOT

  type = object({
    enabled                 = optional(bool, false)
    consumer_role_arns      = optional(list(string), [])
    deletion_window_in_days = optional(number, 30)
    tags                    = optional(map(string), {})
  })

  default = { enabled = false }
}

# ******************************************************
#  k8s Coprocessor Dependencies
# ******************************************************
variable "k8s_coprocessor_deps" {
  description = "Kubernetes coprocessor resource configuration (namespaces, service accounts, storage classes, ExternalName services)."
  type = object({
    enabled = optional(bool, false)

    default_namespace = optional(string, "coproc")

    # Namespaces
    namespaces = optional(map(object({
      enabled     = optional(bool, true)
      labels      = optional(map(string), {})
      annotations = optional(map(string), {})
    })), {})

    # Service accounts — built-in toggles + custom extras.
    service_accounts = optional(object({
      # sns_worker: IRSA role with S3 access (s3:*Object + s3:ListBucket).
      sns_worker = optional(object({
        enabled       = optional(bool, true)
        s3_bucket_key = optional(string, "coprocessor")
      }), {})

      # db_admin: IRSA role with RDS master secret (GetSecretValue + DescribeSecret).
      db_admin = optional(object({
        enabled = optional(bool, true)
      }), {})

      # tx_sender: IRSA role with KMS Sign/Verify on the coprocessor keypair.
      # Set kms_key_access = false to omit the KMS policy (e.g. when the key lives in another account).
      tx_sender = optional(object({
        enabled        = optional(bool, true)
        kms_key_access = optional(bool, true)
      }), {})

      # Additional service accounts. An entry with the same key as a built-in overrides it.
      extra = optional(map(object({
        name                   = string
        namespace              = optional(string, null)
        iam_role_name_override = optional(string, null)
        s3_bucket_access = optional(map(object({
          actions = list(string)
        })), {})
        rds_master_secret_access = optional(bool, false)
        kms_key_access           = optional(bool, false)
        iam_policy_statements = optional(list(object({
          sid       = optional(string, "")
          effect    = string
          actions   = list(string)
          resources = list(string)
          conditions = optional(list(object({
            test     = string
            variable = string
            values   = list(string)
          })), [])
        })), [])
        labels      = optional(map(string), {})
        annotations = optional(map(string), {})
      })), {})
    }), {})

    # Storage classes — built-in toggles + custom extras.
    storage_classes = optional(object({
      # gp3: encrypted EBS gp3, WaitForFirstConsumer, set as cluster default.
      gp3 = optional(object({
        enabled = optional(bool, true)
      }), {})

      # Additional storage classes. An entry with the same key as a built-in overrides it.
      extra = optional(map(object({
        provisioner            = string
        reclaim_policy         = optional(string, "Delete")
        volume_binding_mode    = optional(string, "WaitForFirstConsumer")
        allow_volume_expansion = optional(bool, true)
        parameters             = optional(map(string), {})
        annotations            = optional(map(string), {})
        labels                 = optional(map(string), {})
      })), {})
    }), {})

    # ExternalName services — map key becomes the Service name.
    # When endpoint is omitted the root module resolves it from the matching module output (see local.module_endpoints).
    external_name_services = optional(map(object({
      enabled     = optional(bool, true)
      endpoint    = optional(string, null)
      namespace   = optional(string, null)
      annotations = optional(map(string), {})
    })), {})
  })
  default = { enabled = false }
}

# ******************************************************
#  k8s System Charts
# ******************************************************
variable "k8s_system_charts" {
  description = "Kubernetes system-level applications to deploy via Helm."
  type = object({
    enabled = optional(bool, false)

    # Toggle built-in applications on/off. See modules/k8s-system-charts for full docs.
    defaults = optional(object({
      karpenter_nodepools = optional(object({
        enabled = optional(bool, true)
      }), {})
      prometheus_operator_crds = optional(object({
        enabled    = optional(bool, true)
        repository = optional(string, "https://prometheus-community.github.io/helm-charts")
        chart      = optional(string, "prometheus-operator-crds")
        version    = optional(string, "28.0.1")
      }), {})
      metrics_server = optional(object({
        enabled    = optional(bool, true)
        repository = optional(string, "https://kubernetes-sigs.github.io/metrics-server")
        chart      = optional(string, "metrics-server")
        version    = optional(string, "3.13.0")
        image_tag  = optional(string, "v0.8.0")
        values     = optional(string, "")
      }), {})
      karpenter = optional(object({
        enabled              = optional(bool, true)
        repository           = optional(string, "oci://public.ecr.aws/karpenter")
        chart                = optional(string, "karpenter")
        version              = optional(string, "1.8.2")
        controller_image_tag = optional(string, "v1.11.0")
        values               = optional(string, "")
      }), {})
      k8s_monitoring = optional(object({
        enabled                  = optional(bool, false)
        repository               = optional(string, "https://grafana.github.io/helm-charts")
        chart                    = optional(string, "k8s-monitoring")
        version                  = optional(string, "4.0.1")
        prometheus_url           = optional(string, "")
        loki_url                 = optional(string, "")
        otlp_url                 = optional(string, "")
        alloy_operator_image_tag = optional(string, "v0.5.3")
        alloy_image_tag          = optional(string, "v1.15.0")
        node_exporter_image_tag  = optional(string, "v1.11.0")
        values                   = optional(string, "")
      }), {})
      prometheus_rds_exporter = optional(object({
        enabled    = optional(bool, false)
        repository = optional(string, "oci://public.ecr.aws/qonto")
        chart      = optional(string, "prometheus-rds-exporter-chart")
        version    = optional(string, "0.16.0")
        values     = optional(string, "")
      }), {})
      prometheus_postgres_exporter = optional(object({
        enabled    = optional(bool, false)
        repository = optional(string, "https://prometheus-community.github.io/helm-charts")
        chart      = optional(string, "prometheus-postgres-exporter")
        version    = optional(string, "7.3.0")
        image_tag  = optional(string, "v0.19.1")
        values     = optional(string, "")
      }), {})
    }), {})

    # Additional custom applications. An entry with the same key as a built-in overrides it.
    extra = optional(map(object({
      namespace = object({
        name   = string
        create = optional(bool, false)
      })
      service_account = optional(object({
        create      = optional(bool, false)
        name        = optional(string, null)
        labels      = optional(map(string), {})
        annotations = optional(map(string), {})
      }), null)
      irsa = optional(object({
        enabled   = optional(bool, false)
        role_name = optional(string, null)
        policy_statements = optional(list(object({
          sid       = optional(string, "")
          effect    = string
          actions   = list(string)
          resources = list(string)
        })), [])
      }), { enabled = false })
      helm_chart = optional(object({
        enabled          = optional(bool, true)
        repository       = string
        chart            = string
        version          = string
        values           = optional(string, "")
        set              = optional(map(string), {})
        crd_chart        = optional(bool, false)
        create_namespace = optional(bool, false)
        atomic           = optional(bool, true)
        wait             = optional(bool, true)
        timeout          = optional(number, 300)
      }), null)
      additional_manifests = optional(object({
        enabled   = optional(bool, false)
        manifests = optional(map(string), {})
      }), { enabled = false })
    })), {})
  })
  default = { enabled = false }
}
