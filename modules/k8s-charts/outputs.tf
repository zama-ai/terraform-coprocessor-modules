output "helm_release_statuses" {
  description = "Map of application name to Helm release status."
  value       = { for key, release in helm_release.this : key => release.status }
}

output "irsa_role_arns" {
  description = "Map of application name to IRSA IAM role ARN. Only populated for applications with irsa.enabled = true."
  value       = { for key, role in aws_iam_role.irsa : key => role.arn }
}

output "namespace_names" {
  description = "Map of application name to namespace name, for namespaces created by this module."
  value       = { for key, ns in kubernetes_namespace.this : key => ns.metadata[0].name }
}

output "service_account_names" {
  description = "Map of application name to service account name, for service accounts created by this module."
  value       = { for key, sa in kubernetes_service_account.this : key => sa.metadata[0].name }
}
