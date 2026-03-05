output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the cluster."
  value       = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA."
  value       = module.eks.oidc_provider_arn
}

output "karpenter_iam_role_arn" {
  description = "Karpenter controller IAM role ARN. Null when Karpenter is disabled."
  value       = var.karpenter.enabled ? module.karpenter[0].iam_role_arn : null
}

output "karpenter_node_iam_role_arn" {
  description = "IAM role ARN attached to Karpenter-launched nodes. Null when Karpenter is disabled."
  value       = var.karpenter.enabled ? module.karpenter[0].node_iam_role_arn : null
}

output "karpenter_queue_name" {
  description = "SQS queue name for Karpenter interruption handling. Null when Karpenter is disabled."
  value       = var.karpenter.enabled ? module.karpenter[0].queue_name : null
}
