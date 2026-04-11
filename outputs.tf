# ******************************************************
#  Networking
# ******************************************************
output "vpc_id" {
  description = "The ID of the VPC."
  value       = local.vpc_id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs."
  value       = local.private_subnet_ids
}

output "additional_subnet_ids" {
  description = "List of additional subnet IDs."
  value       = local.additional_subnet_ids
}

# ******************************************************
#  EKS
# ******************************************************
output "eks_cluster_name" {
  description = "The EKS cluster name."
  value       = one(module.eks[*].cluster_name)
}

output "eks_cluster_endpoint" {
  description = "The EKS cluster API endpoint."
  value       = one(module.eks[*].cluster_endpoint)
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the EKS cluster."
  value       = one(module.eks[*].cluster_certificate_authority_data)
}

output "eks_oidc_provider_arn" {
  description = "The ARN of the OIDC provider for IRSA."
  value       = one(module.eks[*].oidc_provider_arn)
}

output "eks_karpenter_iam_role_arn" {
  description = "IAM role ARN for the Karpenter controller."
  value       = one(module.eks[*].karpenter_iam_role_arn)
}

output "eks_karpenter_node_iam_role_arn" {
  description = "IAM role ARN for Karpenter-managed nodes."
  value       = one(module.eks[*].karpenter_node_iam_role_arn)
}

output "eks_karpenter_queue_name" {
  description = "SQS queue name for Karpenter interruption handling."
  value       = one(module.eks[*].karpenter_queue_name)
}

# ******************************************************
#  RDS
# ******************************************************
output "rds_db_instance_endpoint" {
  description = "The RDS instance connection endpoint (host:port)."
  value       = module.rds.db_instance_endpoint
}

output "rds_db_instance_address" {
  description = "The RDS instance hostname (without port)."
  value       = module.rds.db_instance_address
}

output "rds_db_instance_arn" {
  description = "The ARN of the RDS instance."
  value       = module.rds.db_instance_arn
}

output "rds_security_group_id" {
  description = "The ID of the RDS security group."
  value       = module.rds.security_group_id
}

output "rds_db_instance_identifier" {
  description = "The identifier of the RDS instance."
  value       = module.rds.db_instance_identifier
}

output "rds_db_instance_port" {
  description = "The port the RDS instance is listening on."
  value       = module.rds.db_instance_port
}

output "rds_master_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the RDS master user password. Null when manage_master_user_password = false or rds.enabled = false."
  value       = module.rds.rds_master_secret_arn
}

# ******************************************************
#  S3
# ******************************************************
output "s3_bucket_names" {
  description = "Map of logical bucket key to bucket name."
  value       = module.s3.bucket_names
}

output "s3_bucket_arns" {
  description = "Map of logical bucket key to bucket ARN."
  value       = module.s3.bucket_arns
}

output "s3_cloudfront_domain_names" {
  description = "Map of logical bucket key to CloudFront distribution domain name."
  value       = module.s3.cloudfront_domain_names
}

output "s3_cloudfront_distribution_ids" {
  description = "Map of logical bucket key to CloudFront distribution ID."
  value       = module.s3.cloudfront_distribution_ids
}
