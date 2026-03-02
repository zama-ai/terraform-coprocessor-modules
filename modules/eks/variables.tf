variable "name" {
  description = "EKS cluster name."
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "network" {
  description = "Network inputs for the EKS cluster."
  type = object({
    vpc_id             = string
    private_subnet_ids = list(string)

    # Optional additional subnets (e.g. CNI or specific node groups)
    additional_subnet_ids          = optional(list(string), [])
    node_groups_using_additional_subnets = optional(list(string), [])
  })
}

variable "cluster" {
  description = "EKS cluster configuration."
  type = object({
    kubernetes_version                 = optional(string, null)

    endpoint_public_access             = optional(bool, false)
    endpoint_private_access            = optional(bool, true)
    endpoint_public_access_cidrs       = optional(list(string), [])

    enable_irsa                        = optional(bool, true)
    enable_cluster_creator_admin_permissions = optional(bool, true)
  })
  default = {}
}

variable "addons" {
  description = "EKS addons configuration."
  type = object({
    # Baseline addons enabled by default. You can override/extend via `extra`.
    default = optional(map(any), {
      aws-ebs-csi-driver = { most_recent = true }
      coredns            = { most_recent = true }
      kube-proxy         = { most_recent = true }
      vpc-cni            = { most_recent = true }
    })

    # Optional configuration values for VPC CNI. This is JSON-encoded and fed to the addon.
    vpc_cni_config = optional(any, {})

    # Additional / override addons (merged over `default`)
    extra = optional(map(any), {})
  })
  default = {}
}

variable "node_groups" {
  description = "EKS managed node groups configuration."
  type = object({
    defaults = optional(map(any), {})

    # Default IAM role policies merged into each node group's `iam_role_additional_policies`.
    default_iam_role_additional_policies = optional(map(string), {})

    managed = optional(map(any), {})
  })
  default = {}
}

variable "access" {
  description = "EKS access entries (cluster admin roles, etc.)."
  type = object({
    admin_role_arns = optional(list(string), [])
  })
  default = {}
}

variable "karpenter" {
  description = "Karpenter configuration."
  type = object({
    enabled = optional(bool, false)

    namespace       = optional(string, "karpenter")
    service_account = optional(string, "karpenter")

    # Karpenter module names (override if you need strict naming conventions)
    queue_name       = optional(string, null)
    rule_name_prefix = optional(string, null)

    # Attach additional IAM policies to the Karpenter *node* role
    node_iam_role_additional_policies = optional(map(string), {})

    # Optional dedicated controller node group (useful if you don't want Karpenter scheduling itself)
    controller_nodegroup_enabled = optional(bool, false)
    controller_nodegroup_config  = optional(map(any), {})
  })
  default = {}
}
