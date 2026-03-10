variable "name" {
  description = "Name prefix for all EKS resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. devnet, mainnet, testnet)."
  type        = string
}

# ******************************************************
#  Networking inputs (from networking module outputs)
# ******************************************************
variable "vpc_id" {
  description = "VPC ID to deploy the cluster into."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the EKS control plane and default node groups."
  type        = list(string)
}

variable "additional_subnet_ids" {
  description = "Additional subnet IDs for node groups that require them."
  type        = list(string)
  default     = []
}

# ******************************************************
#  Cluster
# ******************************************************
variable "cluster" {
  description = "EKS cluster configuration."
  type = object({
    version       = optional(string, "1.32")
    name_override = optional(string, null)

    endpoint_public_access       = optional(bool, false)
    endpoint_private_access      = optional(bool, true)
    endpoint_public_access_cidrs = optional(list(string), [])

    enable_irsa                      = optional(bool, true)
    enable_creator_admin_permissions = optional(bool, true)

    admin_role_arns = optional(list(string), [])
  })
  default = {}

  validation {
    condition     = can(regex("^1\\.(2[8-9]|[3-9][0-9])$", var.cluster.version))
    error_message = "EKS cluster version must be 1.28 or higher."
  }
}

# ******************************************************
#  Addons
# ******************************************************
variable "addons" {
  description = "EKS addon configuration."
  type = object({
    defaults = optional(map(any), {
      aws-ebs-csi-driver     = { most_recent = true }
      coredns                = { most_recent = true }
      vpc-cni                = { most_recent = true, before_compute = true }
      kube-proxy             = { most_recent = true }
      eks-pod-identity-agent = { most_recent = true, before_compute = true }
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
  })
  default = {}
}

# ******************************************************
#  Node Groups
# ******************************************************
variable "node_groups" {
  description = "EKS managed node group configuration."
  type = object({
    defaults = optional(map(any), {})

    default_iam_policies = optional(map(string), {
      AmazonEBSCSIDriverPolicy           = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
      AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
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
      }), { max_unavailable = 1 })
      taints = optional(map(object({
        key    = string
        value  = optional(string)
        effect = string
      })), {})
      iam_role_additional_policies = optional(map(string), {})
      metadata_options = optional(map(string), {
        http_endpoint               = "enabled"
        http_put_response_hop_limit = "1"
        http_tokens                 = "required"
      })
      })), {
      default = {
        capacity_type  = "ON_DEMAND"
        min_size       = 1
        max_size       = 3
        desired_size   = 1
        instance_types = ["t3.medium"]
        disk_size      = 30
        update_config  = { max_unavailable = 1 }
      }
    })
  })
  default = {}
}

# ******************************************************
#  Karpenter
# ******************************************************
variable "karpenter" {
  description = "Karpenter configuration. Set enabled = false to skip all Karpenter resources."
  type = object({
    enabled          = optional(bool, false)
    namespace        = optional(string, "karpenter")
    service_account  = optional(string, "karpenter")
    queue_name       = optional(string, null)
    rule_name_prefix = optional(string, null)

    create_spot_service_linked_role = optional(bool, true)

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
  })
  default = { enabled = false }

  validation {
    condition     = var.karpenter.rule_name_prefix == null || length(var.karpenter.rule_name_prefix) <= 20
    error_message = "karpenter.rule_name_prefix must be 20 characters or less."
  }
}
