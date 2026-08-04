module "coprocessor" {
  source = "../../"

  partner_name = var.partner_name
  environment  = var.environment
  aws_region   = var.aws_region
  default_tags = var.default_tags

  networking           = var.networking
  eks                  = var.eks
  rds                  = var.rds
  s3                   = var.s3
  kms                  = var.kms
  k8s_coprocessor_deps = var.k8s_coprocessor_deps
  kubernetes_provider  = var.kubernetes_provider
}
