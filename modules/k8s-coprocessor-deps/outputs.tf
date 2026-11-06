output "storage_class_names" {
  description = "Map of logical storage class key to storage class name."
  value       = { for key, value in kubernetes_storage_class_v1.this : key => value.metadata[0].name }
}

output "iam_role_arns" {
  description = "Map of logical service account key to IRSA IAM role ARN. Only includes service accounts with iam_policy_statements."
  value       = { for key, value in aws_iam_role.service_account : key => value.arn }
}

output "iam_role_names" {
  description = "Map of logical service account key to IRSA IAM role name. Only includes service accounts with iam_policy_statements."
  value       = { for key, value in aws_iam_role.service_account : key => value.name }
}

output "namespace" {
  description = "Kubernetes namespace for coprocessor resources. Null when k8s is disabled."
  value       = var.k8s.enabled ? local.namespace : null
}

output "service_account_names" {
  description = "Map of logical service account key to Kubernetes service account name."
  value       = { for key, value in kubernetes_service_account.this : key => value.metadata[0].name }
}

output "config_map_names" {
  description = "Map of \"<namespace>/<name>\" to ConfigMap name for the ConfigMaps this module manages."
  value = merge(
    { for cm in kubernetes_config_map.db_admin_config :
    "${cm.metadata[0].namespace}/${cm.metadata[0].name}" => cm.metadata[0].name },
    { for cm in kubernetes_config_map.coprocessor_config :
    "${cm.metadata[0].namespace}/${cm.metadata[0].name}" => cm.metadata[0].name },
  )
}

output "security_group_policy_names" {
  description = "Map of logical SecurityGroupPolicy key to the policy name, for the SGPs this module manages."
  value = {
    for key, sgp in kubernetes_manifest.security_group_policy :
    key => sgp.manifest.metadata.name
  }
}
