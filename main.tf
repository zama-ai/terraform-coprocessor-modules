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
#  k8s
# ******************************************************
module "k8s" {
  source = "./modules/k8s"

  partner_name = var.partner_name
  environment  = var.environment

  oidc_provider_arn = (
    var.kubernetes_provider.oidc_provider_arn != null
    ? var.kubernetes_provider.oidc_provider_arn
    : one(module.eks[*].oidc_provider_arn) != null
    ? one(module.eks[*].oidc_provider_arn)
    : ""
  )

  rds_endpoint          = module.rds.db_instance_address
  rds_master_secret_arn = module.rds.rds_master_secret_arn
  s3_bucket_arns        = module.s3.bucket_arns

  k8s = var.k8s
}

# ******************************************************
#  k8s Charts
# ******************************************************
module "k8s_charts" {
  count  = var.k8s_charts.enabled ? 1 : 0
  source = "./modules/k8s-charts"

  partner_name = var.partner_name
  environment  = var.environment

  oidc_provider_arn = (
    var.kubernetes_provider.oidc_provider_arn != null
    ? var.kubernetes_provider.oidc_provider_arn
    : one(module.eks[*].oidc_provider_arn) != null
    ? one(module.eks[*].oidc_provider_arn)
    : ""
  )

  applications = var.k8s_charts.applications

  set_computed = {
    karpenter = {
      "settings.clusterName"       = local.eks_cluster_name
      "settings.interruptionQueue" = one(module.eks[*].karpenter_queue_name) != null ? one(module.eks[*].karpenter_queue_name) : ""
      "settings.eksControlPlane"   = "true"
    }
    k8s-monitoring = {
      "cluster.name" = local.eks_cluster_name

      # Injected into both destinations so every metric and log line carries
      # consistent partner/network dimensions across all Grafana Cloud stacks.
      # destinations[0] = grafana-cloud-metrics (prometheus)
      # destinations[1] = grafana-cloud-logs    (loki)
      "destinations[0].externalLabels.partner" = var.partner_name
      "destinations[0].externalLabels.network" = var.environment
      "destinations[1].externalLabels.partner" = var.partner_name
      "destinations[1].externalLabels.network" = var.environment
    }
    prometheus-rds-exporter = {
      "prometheus-rds-exporter-chart.serviceMonitor.relabelings[0].replacement" = var.environment
    }
    prometheus-postgres-exporter = {
      "serviceMonitor.relabelings[0].replacement" = var.environment
    }
  }
}
