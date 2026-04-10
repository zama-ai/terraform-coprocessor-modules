variable "partner_name" {
  description = "Partner identifier — used as a name prefix across all resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. testnet, mainnet)."
  type        = string
}

variable "aws_region" {
  description = "AWS region where resources will be deployed."
  type        = string
}

variable "default_tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}

# Complex configuration objects use type = any here to avoid duplicating the full
# type definitions from the root module. Validation is enforced by the module itself.

variable "networking" {
  description = "VPC and subnet configuration. See root module variables.tf for full schema."
  type        = any
  default     = { enabled = true }
}

variable "eks" {
  description = "EKS cluster configuration. See root module variables.tf for full schema."
  type        = any
  default     = { enabled = true }
}

variable "rds" {
  description = "RDS instance configuration. See root module variables.tf for full schema."
  type        = any
  default     = { enabled = true }
}

variable "s3" {
  description = "S3 bucket configuration. See root module variables.tf for full schema."
  type        = any
  default     = { buckets = {} }
}

variable "k8s_coprocessor_deps" {
  description = "Kubernetes coprocessor resource configuration. See root module variables.tf for full schema."
  type        = any
  default     = { enabled = false }
}

variable "kubernetes_provider" {
  description = "Kubernetes provider configuration for BYOC deployments. See root module variables.tf for full schema."
  type        = any
  default     = {}
}
