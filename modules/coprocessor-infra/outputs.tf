output "coprocessor_bucket_storage_summary" {
  description = "Summary of the coprocessor bucket storage"
  value = {
    coprocessor_bucket_name        = aws_s3_bucket.coprocessor_bucket.id
    coprocessor_bucket_arn         = aws_s3_bucket.coprocessor_bucket.arn
    coprocessor_bucket_domain_name = aws_s3_bucket.coprocessor_bucket.bucket_domain_name
    coprocessor_bucket_url         = "https://${aws_s3_bucket.coprocessor_bucket.bucket_domain_name}"
  }
}

# Kubernetes Service Account Information
output "k8s_coprocessor_service_account_summary" {
  description = "Summary of the Kubernetes service account for Coprocessor party"
  value = {
    service_account_name              = var.k8s_coprocessor_service_account_name
    service_account_created           = var.create_service_account
    service_account_namespace         = var.k8s_coprocessor_namespace
    service_account_namespace_created = var.create_coprocessor_namespace
    service_account_role_arn          = var.create_service_account ? module.iam_assumable_role_coprocessor.iam_role_arn : null
  }
}

# RDS Information
output "rds_summary" {
  description = "Aggregated RDS database information"
  value = var.enable_rds ? {
    db_name  = module.rds_instance[0].db_instance_name
    endpoint = module.rds_instance[0].db_instance_endpoint
    port     = module.rds_instance[0].db_instance_port
    username = nonsensitive(module.rds_instance[0].db_instance_username)
  } : null
}
