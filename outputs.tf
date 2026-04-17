# ******************************************************
#  Root Outputs
# ******************************************************
output "outputs" {
  description = "Consolidated root module outputs."

  value = {
    vpc_id                                 = local.vpc_id
    private_subnet_ids                     = local.private_subnet_ids
    additional_subnet_ids                  = local.additional_subnet_ids
    eks_cluster_name                       = one(module.eks[*].cluster_name)
    eks_cluster_endpoint                   = one(module.eks[*].cluster_endpoint)
    eks_cluster_certificate_authority_data = one(module.eks[*].cluster_certificate_authority_data)
    eks_oidc_provider_arn                  = one(module.eks[*].oidc_provider_arn)
    eks_karpenter_iam_role_arn             = one(module.eks[*].karpenter_iam_role_arn)
    eks_karpenter_node_iam_role_arn        = one(module.eks[*].karpenter_node_iam_role_arn)
    eks_karpenter_queue_name               = one(module.eks[*].karpenter_queue_name)
    rds_db_instance_endpoint               = module.rds.db_instance_endpoint
    rds_db_instance_address                = module.rds.db_instance_address
    rds_db_instance_arn                    = module.rds.db_instance_arn
    rds_security_group_id                  = module.rds.security_group_id
    rds_db_instance_identifier             = module.rds.db_instance_identifier
    rds_db_instance_port                   = module.rds.db_instance_port
    rds_master_secret_arn                  = module.rds.rds_master_secret_arn
    s3_bucket_names                        = module.s3.bucket_names
    s3_bucket_arns                         = module.s3.bucket_arns
    s3_cloudfront_domain_names             = module.s3.cloudfront_domain_names
    s3_cloudfront_distribution_ids         = module.s3.cloudfront_distribution_ids
  }
}
