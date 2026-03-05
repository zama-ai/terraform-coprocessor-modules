# ******************************************************
#  Core
# ******************************************************
variable "partner_name" {
  description = "Partner identifier — used as a name prefix across all resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. devnet, mainnet, testnet)."
  type        = string

  validation {
    condition     = contains(["devnet", "testnet", "mainnet"], var.environment)
    error_message = "environment must be either 'devnet', 'testnet', or 'mainnet'."
  }
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
#  Networking
# ******************************************************
variable "networking" {
  description = "VPC and subnet configuration."
  type = object({
    vpc = object({
      cidr                     = string
      availability_zones       = optional(list(string), [])
      single_nat_gateway       = optional(bool, false)
      use_subnet_calc_v2       = optional(bool, true)
      private_subnet_cidr_mask = optional(number, 20)
      public_subnet_cidr_mask  = optional(number, 24)
      flow_log_enabled         = optional(bool, false)
      flow_log_destination_arn = optional(string, null)
    })

    additional_subnets = optional(object({
      enabled        = optional(bool, false)
      cidr_mask      = optional(number, 22)
      expose_for_eks = optional(bool, false)
      elb_role       = optional(string, null)
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
    condition     = can(cidrhost(var.networking.vpc.cidr, 0))
    error_message = "networking.vpc.cidr must be a valid IPv4 CIDR block."
  }
}

# ******************************************************
#  EKS
# ******************************************************
variable "eks" {
  description = "EKS cluster configuration."
  type = object({
    cluster = optional(object({
      version                          = optional(string, "1.32")
      endpoint_public_access           = optional(bool, true)
      endpoint_private_access          = optional(bool, true)
      endpoint_public_access_cidrs     = optional(list(string), [])
      enable_irsa                      = optional(bool, true)
      enable_creator_admin_permissions = optional(bool, true)
      admin_role_arns                  = optional(list(string), [])
    }), {})

    addons = optional(object({
      defaults = optional(map(any), {
        aws-ebs-csi-driver     = { most_recent = true }
        coredns                = { most_recent = true }
        vpc-cni                = { most_recent = true, before_compute = true }
        kube-proxy             = { most_recent = true }
        eks-pod-identity-agent = { most_recent = true }
      })
      extra = optional(map(any), {})
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
      defaults             = optional(map(any), {})
      default_iam_policies = optional(map(string), {
        AmazonEBSCSIDriverPolicy           = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
      })
      groups = optional(map(object({
        capacity_type              = optional(string, "ON_DEMAND")
        min_size                   = optional(number, 1)
        max_size                   = optional(number, 3)
        desired_size               = optional(number, 1)
        instance_types             = optional(list(string), ["t3.medium"])
        ami_type                   = optional(string, "AL2023_x86_64_STANDARD")
        use_custom_launch_template = optional(bool, false)
        disk_size                  = optional(number, 30)
        disk_type                  = optional(string, "gp3")
        labels                     = optional(map(string), {})
        tags                       = optional(map(string), {})
        use_additional_subnets     = optional(bool, false)
        update_config = optional(object({
          max_unavailable            = optional(number)
          max_unavailable_percentage = optional(number)
        }), {})
        taints = optional(map(object({
          key    = string
          value  = optional(string)
          effect = string
        })), {})
        iam_role_additional_policies = optional(map(string), {})
        metadata_options = optional(map(string), {
          http_endpoint               = "enabled"
          http_put_response_hop_limit = "2"
          http_tokens                 = "required"
        })
      })), {})
    }), {})

    karpenter = optional(object({
      enabled          = optional(bool, false)
      namespace        = optional(string, "karpenter")
      service_account  = optional(string, "karpenter")
      queue_name       = optional(string, null)
      rule_name_prefix = optional(string, null)
      node_iam_role_additional_policies = optional(map(string), {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      })
      controller_nodegroup = optional(object({
        enabled        = optional(bool, false)
        capacity_type  = optional(string, "ON_DEMAND")
        min_size       = optional(number, 1)
        max_size       = optional(number, 2)
        desired_size   = optional(number, 1)
        instance_types = optional(list(string), ["t3.small"])
        ami_type       = optional(string, "AL2023_x86_64_STANDARD")
        disk_size      = optional(number, 50)
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
      }), { enabled = false })
    }), { enabled = false })
  })
}

# ******************************************************
#  RDS
# ******************************************************
variable "rds" {
  description = "RDS instance configuration. Set enabled = false to skip."

  type = object({
    enabled = optional(bool, false)

    db_name             = optional(string, null)
    identifier_override = optional(string, null)

    engine         = optional(string, "postgres")
    engine_version = optional(number, 17)

    instance_class        = optional(string, "db.t4g.medium")
    allocated_storage     = optional(number, 20)
    max_allocated_storage = optional(number, 100)
    multi_az              = optional(bool, false)
    port                  = optional(number, 5432)

    username                         = optional(string, "postgres")
    password                         = optional(string, null)
    enable_master_password_rotation  = optional(bool, false)
    master_password_rotation_days    = optional(number, 7)

    maintenance_window      = optional(string, "Mon:00:00-Mon:03:00")
    backup_retention_period = optional(number, 7)
    deletion_protection     = optional(bool, true)

    monitoring_interval    = optional(number, 60)
    create_monitoring_role = optional(bool, true)
    monitoring_role_name   = optional(string, null)
    monitoring_role_arn    = optional(string, null)

    parameters = optional(list(object({
      name  = string
      value = string
    })), [])

    allowed_cidr_blocks = optional(list(string), [])
  })

  default = { enabled = false }
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
      purpose       = string

      # Allow deletion even if objects exist
      force_destroy = optional(bool, false)

      # Enable object versioning
      versioning    = optional(bool, true)

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

      # Bucket policies
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
      })), [])
    }))
  })

  default = { buckets = {} }
}