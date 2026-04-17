# ******************************************************
#  Networking
# ******************************************************
output "vpc_id" {
  description = "ID of the created VPC."
  value       = module.coprocessor.outputs.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = module.coprocessor.outputs.private_subnet_ids
}

# ******************************************************
#  EKS
# ******************************************************
output "eks_cluster_name" {
  description = "EKS cluster name."
  value       = module.coprocessor.outputs.eks_cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint."
  value       = module.coprocessor.outputs.eks_cluster_endpoint
}

output "eks_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA."
  value       = module.coprocessor.outputs.eks_oidc_provider_arn
}

output "eks_karpenter_iam_role_arn" {
  description = "IAM role ARN for the Karpenter controller."
  value       = module.coprocessor.outputs.eks_karpenter_iam_role_arn
}

output "eks_karpenter_node_iam_role_arn" {
  description = "IAM role ARN for Karpenter-managed nodes."
  value       = module.coprocessor.outputs.eks_karpenter_node_iam_role_arn
}

output "eks_karpenter_queue_name" {
  description = "SQS queue name for Karpenter interruption handling."
  value       = module.coprocessor.outputs.eks_karpenter_queue_name
}

# ******************************************************
#  RDS
# ******************************************************
output "rds_db_instance_endpoint" {
  description = "RDS connection endpoint (host:port)."
  value       = module.coprocessor.outputs.rds_db_instance_endpoint
}

output "rds_db_instance_identifier" {
  description = "RDS instance identifier."
  value       = module.coprocessor.outputs.rds_db_instance_identifier
}

output "rds_master_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the RDS master user password."
  value       = module.coprocessor.outputs.rds_master_secret_arn
}

# ******************************************************
#  S3
# ******************************************************
output "s3_bucket_names" {
  description = "Map of logical bucket key to bucket name."
  value       = module.coprocessor.outputs.s3_bucket_names
}

output "s3_bucket_arns" {
  description = "Map of logical bucket key to bucket ARN."
  value       = module.coprocessor.outputs.s3_bucket_arns
}

output "s3_cloudfront_domain_names" {
  description = "Map of logical bucket key to CloudFront distribution hostname (e.g. d1234abcd.cloudfront.net)."
  value       = module.coprocessor.outputs.s3_cloudfront_domain_names
}
