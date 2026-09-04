# ******************************************************
#  Data sources
# ******************************************************
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# ******************************************************
#  Locals
# ******************************************************
locals {
  # Pre-computed cluster name shared between networking (subnet tags) and EKS
  eks_cluster_name = "${var.partner_name}-${var.environment}"

  # Shared networking resolution — prefer existing_vpc values when provided, fall back to networking module outputs
  vpc_id                     = coalesce(try(var.networking.existing_vpc.vpc_id, null), one(module.networking[*].vpc_id))
  private_subnet_ids         = coalesce(try(var.networking.existing_vpc.private_subnet_ids, null), one(module.networking[*].private_subnet_ids))
  private_subnet_cidr_blocks = coalesce(try(var.networking.existing_vpc.private_subnet_cidr_blocks, null), one(module.networking[*].private_subnet_cidr_blocks), [])

  # tx-sender IRSA role ARN — computed as a string from the partner/env naming pattern
  # used by k8s-coprocessor-deps. Computing it here (not via module output) breaks the
  # otherwise-circular dependency between kms (consumer_role_arns) and k8s-coprocessor-deps
  # (kms_key_arn → tx-sender IAM policy).
  tx_sender_role_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/tx-sender-${var.partner_name}-${var.environment}"

  # Additional subnets have no existing_vpc equivalent — only available when networking module ran and additional subnets were enabled
  additional_subnet_ids         = var.networking.enabled && var.networking.additional_subnets.enabled ? module.networking[0].additional_subnet_ids : []
  additional_subnet_cidr_blocks = var.networking.enabled && var.networking.additional_subnets.enabled ? module.networking[0].additional_subnet_cidr_blocks : []

  # Data services are reachable from both the base private subnets and any
  # additional private subnets used by EKS node groups or Karpenter.
  all_private_subnet_cidr_blocks = concat(local.private_subnet_cidr_blocks, local.additional_subnet_cidr_blocks)

  # Pod-side client SGs, one per database. Each database has its own client SG
  # and its own SecurityGroupPolicy pod label, so a pod reaches only the database
  # whose label it carries. Keys are driven by the enabled flags alone, so they
  # are known at plan time and can drive for_each.
  rds_client_security_group_ids = merge(
    var.rds.enabled ? { coprocessor = module.rds.rds_client_security_group_id } : {},
    var.listener_rds.enabled ? { listener = module.listener_rds.rds_client_security_group_id } : {},
  )

  # ExternalName service endpoints — explicit tfvars value takes precedence, otherwise resolved from module outputs
  module_endpoints = {
    coprocessor-database = module.rds.db_instance_address
    listener-database    = module.listener_rds.db_instance_address
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
  private_subnet_cidr_blocks = local.all_private_subnet_cidr_blocks

  rds = var.rds
}

# ******************************************************
#  Listener RDS
# ******************************************************
# Dedicated instance for the listener component. It gets its own client and
# server SGs (listener-client / listener-server, named from listener_rds.db_name)
# and its own SecurityGroupPolicy pod label, so only pods labelled for the
# listener can reach it — coprocessor pods cannot, and vice versa.
module "listener_rds" {
  source = "./modules/rds"

  partner_name = var.partner_name
  environment  = var.environment

  vpc_id                     = local.vpc_id
  private_subnet_ids         = local.private_subnet_ids
  private_subnet_cidr_blocks = local.all_private_subnet_cidr_blocks

  rds = var.listener_rds
}

# Pods carrying a database's client SG (via SecurityGroupPolicy) get a branch ENI
# that holds only that SG. One pair of rules is created per database, since each
# has its own client SG. To reach intra-cluster destinations these pods need
# ingress allowed on the SGs of those destinations:
#   - kube-apiserver (control plane ENIs)     -> cluster primary SG
#   - CoreDNS / pods running on cluster nodes -> node SG
#     (one shared node SG covers managed NGs and Karpenter nodes via the
#      karpenter.sh/discovery tag selector on the EC2NodeClass)
resource "aws_vpc_security_group_ingress_rule" "cluster_from_rds_client" {
  for_each = var.eks.enabled ? local.rds_client_security_group_ids : {}

  security_group_id            = one(module.eks[*].cluster_primary_security_group_id)
  referenced_security_group_id = each.value
  ip_protocol                  = "-1"
  description                  = "Allow ${each.key} rds-client pods to reach the EKS kube-apiserver (control plane ENIs)"
}

resource "aws_vpc_security_group_ingress_rule" "node_from_rds_client" {
  for_each = var.eks.enabled ? local.rds_client_security_group_ids : {}

  security_group_id            = one(module.eks[*].node_security_group_id)
  referenced_security_group_id = each.value
  ip_protocol                  = "-1"
  description                  = "Allow ${each.key} rds-client pods to reach CoreDNS and other pods running on cluster nodes"
}

# These two rules were previously gated by count, so the single coprocessor
# instance lived at index [0]. Without these moved blocks, an already-deployed
# stack would destroy and recreate them on upgrade, and pods on branch ENIs
# would lose kube-apiserver and CoreDNS access for the duration.
#
# Both are no-ops on a fresh state: Terraform ignores a moved block whose source
# address is absent, and ignores the destination when the key is not in the
# current for_each (e.g. rds.enabled = false).
moved {
  from = aws_vpc_security_group_ingress_rule.cluster_from_rds_client[0]
  to   = aws_vpc_security_group_ingress_rule.cluster_from_rds_client["coprocessor"]
}

moved {
  from = aws_vpc_security_group_ingress_rule.node_from_rds_client[0]
  to   = aws_vpc_security_group_ingress_rule.node_from_rds_client["coprocessor"]
}

# ******************************************************
#  ElastiCache
# ******************************************************
module "elasticache" {
  source = "./modules/elasticache"

  partner_name = var.partner_name
  environment  = var.environment

  vpc_id                     = local.vpc_id
  private_subnet_ids         = local.private_subnet_ids
  private_subnet_cidr_blocks = local.all_private_subnet_cidr_blocks

  elasticache = var.elasticache
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
#  KMS
# ******************************************************
# Wait for tx-sender IAM role to propagate before KMS validates its key policy.
resource "time_sleep" "wait_for_tx_sender_iam_propagation" {
  count = (
    var.kms.enabled
    && var.k8s_coprocessor_deps.enabled
    && var.k8s_coprocessor_deps.service_accounts.tx_sender.enabled
  ) ? 1 : 0

  create_duration = "30s"

  triggers = {
    role_arn = try(module.k8s_coprocessor_deps.iam_role_arns["tx-sender"], "")
  }
}

module "kms" {
  source = "./modules/kms"

  partner_name = var.partner_name
  environment  = var.environment

  # Auto-append the tx-sender IRSA role ARN when the corresponding service account is enabled,
  # so the KMS key policy grants Sign/Verify to the role created by k8s-coprocessor-deps.
  kms = merge(var.kms, {
    consumer_role_arns = concat(
      var.kms.consumer_role_arns,
      var.k8s_coprocessor_deps.enabled && var.k8s_coprocessor_deps.service_accounts.tx_sender.enabled ? [local.tx_sender_role_arn] : [],
    )
  })

  depends_on = [time_sleep.wait_for_tx_sender_iam_propagation]
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

  rds_master_secret_arn                 = module.rds.rds_master_secret_arn
  listener_rds_master_secret_arn        = module.listener_rds.rds_master_secret_arn
  rds_client_security_group_id          = module.rds.rds_client_security_group_id
  listener_rds_client_security_group_id = module.listener_rds.rds_client_security_group_id
  s3_bucket_arns                        = module.s3.bucket_arns
  s3_bucket_names                       = module.s3.bucket_names
  kms_key_arn                           = module.kms.key_arn

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
    region       = var.aws_region
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
