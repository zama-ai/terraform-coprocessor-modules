module "coprocessor" {
  source = "../../"

  partner_name = var.partner_name
  environment  = var.environment
  aws_region   = var.aws_region
  default_tags = var.default_tags

  networking          = var.networking
  eks                 = var.eks
  rds                 = var.rds
  s3                  = var.s3
  k8s                 = var.k8s
  kubernetes_provider = var.kubernetes_provider
}
