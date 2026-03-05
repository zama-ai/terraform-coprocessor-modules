# ******************************************************
#  Locals
# ******************************************************
locals {
  # Pre-computed cluster name shared between networking (subnet tags) and EKS
  eks_cluster_name = "${var.partner_name}-${var.environment}"

  # RDS
  rds_vpc_id                     = coalesce(try(var.networking.existing_vpc.vpc_id, null), module.networking.vpc_id)
  rds_private_subnet_ids         = coalesce(try(var.networking.existing_vpc.private_subnet_ids, null), module.networking.private_subnet_ids)
  rds_private_subnet_cidr_blocks = coalesce(try(var.networking.existing_vpc.private_subnet_cidr_blocks, null), module.networking.private_subnet_cidr_blocks)
}

# ******************************************************
#  Networking
# ******************************************************
module "networking" {
  source = "./modules/networking"

  partner_name = var.partner_name
  environment  = var.environment

  vpc                = var.networking.vpc
  additional_subnets = var.networking.additional_subnets

  eks_cluster_name = local.eks_cluster_name
  enable_karpenter = var.eks.karpenter.enabled
}

# ******************************************************
#  EKS
# ******************************************************
module "eks" {
  source = "./modules/eks"

  name        = var.partner_name
  environment = var.environment
  tags        = var.default_tags

  vpc_id                = module.networking.vpc_id
  private_subnet_ids    = module.networking.private_subnet_ids
  additional_subnet_ids = module.networking.additional_subnet_ids

  cluster     = var.eks.cluster
  addons      = var.eks.addons
  node_groups = var.eks.node_groups
  karpenter   = var.eks.karpenter
}

# ******************************************************
#  RDS
# ******************************************************
module "rds" {
  source = "./modules/rds"

  partner_name = var.partner_name
  environment  = var.environment

  vpc_id                     = local.rds_vpc_id
  private_subnet_ids         = local.rds_private_subnet_ids
  private_subnet_cidr_blocks = local.rds_private_subnet_cidr_blocks

  rds = var.rds
}

# ******************************************************
#  S3
# ******************************************************
module "s3" {
  source = "./modules/s3"

  partner_name = var.partner_name
  environment  = var.environment

  buckets = var.s3.buckets
}
