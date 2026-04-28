# ******************************************************
#  Locals
# ******************************************************
locals {
  # Pre-computed cluster name shared between networking (subnet tags) and EKS
  eks_cluster_name = "${var.partner_name}-${var.environment}"

  # Shared networking resolution — prefer existing_vpc values when provided, fall back to networking module outputs
  vpc_id                     = coalesce(try(var.networking.existing_vpc.vpc_id, null), one(module.networking[*].vpc_id))
  private_subnet_ids         = coalesce(try(var.networking.existing_vpc.private_subnet_ids, null), one(module.networking[*].private_subnet_ids))
  private_subnet_cidr_blocks = coalesce(try(var.networking.existing_vpc.private_subnet_cidr_blocks, null), one(module.networking[*].private_subnet_cidr_blocks))

  # Additional subnets have no existing_vpc equivalent — only available when networking module ran and additional subnets were enabled
  additional_subnet_ids = var.networking.enabled && var.networking.additional_subnets.enabled ? module.networking[0].additional_subnet_ids : []

  # ExternalName service endpoints — explicit tfvars value takes precedence, otherwise resolved from module outputs
  module_endpoints = {
    coprocessor-database = module.rds.db_instance_address
  }

  k8s_config = merge(var.k8s_coprocessor_deps, {
    external_name_services = {
      for key, svc in var.k8s_coprocessor_deps.external_name_services :
      key => merge(svc, {
        endpoint = svc.endpoint != null ? svc.endpoint : lookup(local.module_endpoints, key, null)
      })
    }
  })
}

# ******************************************************
#  Networking
# ******************************************************
module "networking" {
  count  = var.networking.enabled ? 1 : 0
  source = "./modules/networking"

  partner_name = var.partner_name
  environment  = var.environment

  vpc                = var.networking.vpc
  additional_subnets = var.networking.additional_subnets

  eks_cluster_name = local.eks_cluster_name
  enable_karpenter = var.eks.enabled && var.eks.karpenter.enabled
}

# ******************************************************
#  EKS
# ******************************************************
module "eks" {
  count  = var.eks.enabled ? 1 : 0
  source = "./modules/eks"

  name        = var.partner_name
  environment = var.environment

  vpc_id                = local.vpc_id
  private_subnet_ids    = local.private_subnet_ids
  additional_subnet_ids = local.additional_subnet_ids

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

  vpc_id                     = local.vpc_id
  private_subnet_ids         = local.private_subnet_ids
  private_subnet_cidr_blocks = local.private_subnet_cidr_blocks

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

# ******************************************************
#  k8s Coprocessor Dependencies
# ******************************************************
module "k8s_coprocessor_deps" {
  source = "./modules/k8s-coprocessor-deps"

  partner_name = var.partner_name
  environment  = var.environment

  oidc_provider_arn = (
    var.kubernetes_provider.oidc_provider_arn != null
    ? var.kubernetes_provider.oidc_provider_arn
    : one(module.eks[*].oidc_provider_arn) != null
    ? one(module.eks[*].oidc_provider_arn)
    : ""
  )

  rds_master_secret_arn = module.rds.rds_master_secret_arn
  s3_bucket_arns        = module.s3.bucket_arns
  s3_bucket_names       = module.s3.bucket_names

  k8s = local.k8s_config

  depends_on = [module.eks]
}

# ******************************************************
#  k8s System Charts
# ******************************************************
module "k8s_system_charts" {
  count  = var.k8s_system_charts.enabled ? 1 : 0
  source = "./modules/k8s-system-charts"

  partner_name = var.partner_name
  environment  = var.environment

  oidc_provider_arn = (
    var.kubernetes_provider.oidc_provider_arn != null
    ? var.kubernetes_provider.oidc_provider_arn
    : one(module.eks[*].oidc_provider_arn) != null
    ? one(module.eks[*].oidc_provider_arn)
    : ""
  )

  defaults = var.k8s_system_charts.defaults
  extra    = var.k8s_system_charts.extra

  manifests_vars = {
    cluster_name = local.eks_cluster_name
    node_role    = "${local.eks_cluster_name}-Karpenter"
  }

  set_computed = {
    karpenter = {
      "settings.clusterName"       = local.eks_cluster_name
      "settings.interruptionQueue" = one(module.eks[*].karpenter_queue_name) != null ? one(module.eks[*].karpenter_queue_name) : ""
      "settings.eksControlPlane"   = "true"
    }
    k8s-monitoring = {
      "cluster.name" = local.eks_cluster_name
    }
    prometheus-rds-exporter = {
      "prometheus-rds-exporter-chart.serviceMonitor.relabelings[0].replacement" = var.environment
    }
    prometheus-postgres-exporter = {
      "serviceMonitor.relabelings[0].replacement" = var.environment
    }
  }

  depends_on = [module.eks]
}
