variable "partner_name" {
  description = "Name prefix for all networking resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. devnet, mainnet, testnet)."
  type        = string
}

variable "vpc" {
  description = "VPC and subnet configuration."
  type = object({
    cidr               = string
    availability_zones = optional(list(string), [])
    single_nat_gateway = optional(bool, false)

    # V2 subnet calculation (recommended)
    use_subnet_calc_v2       = optional(bool, true)
    private_subnet_cidr_mask = optional(number, 20)
    public_subnet_cidr_mask  = optional(number, 24)

    # Flow logs
    flow_log_enabled         = optional(bool, false)
    flow_log_destination_arn = optional(string, null)
  })
}

variable "additional_subnets" {
  description = "Optional additional subnets, e.g. for CNI or specific node groups."
  type = object({
    enabled        = optional(bool, false)
    cidr_mask      = optional(number, 22)
    expose_for_eks = optional(bool, false)
    elb_role       = optional(string, null) # "internal" | "public" | null
    tags           = optional(map(string), {})
  })
  default = { enabled = false }
}

# Passed in from EKS module so networking can tag subnets correctly
variable "eks_cluster_name" {
  description = "EKS cluster name, used for subnet discovery tags."
  type        = string
}

variable "enable_karpenter" {
  description = "Whether Karpenter is enabled — affects subnet discovery tags."
  type        = bool
  default     = false
}