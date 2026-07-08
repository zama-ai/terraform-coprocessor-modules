# ***************************************
#  Data sources (optional EKS discovery)
#
#  When var.cluster_name is set, discover the VPC and its private subnets
#  (map_public_ip_on_launch = false) from the EKS cluster, so the module can
#  run as a standalone stack. Explicit vpc_id / private_subnet_* inputs always
#  win over discovered values.
# ***************************************
data "aws_eks_cluster" "cluster" {
  count = var.cluster_name != null ? 1 : 0
  name  = var.cluster_name
}

data "aws_subnet" "cluster_subnets" {
  for_each = var.cluster_name != null ? toset(data.aws_eks_cluster.cluster[0].vpc_config[0].subnet_ids) : toset([])
  id       = each.value
}

# ***************************************
#  Local variables
# ***************************************
locals {
  # Discovered networking (empty when cluster_name is not set)
  discovered_vpc_id = var.cluster_name != null ? data.aws_eks_cluster.cluster[0].vpc_config[0].vpc_id : null
  discovered_private_subnet_ids = [
    for subnet_id, subnet in data.aws_subnet.cluster_subnets : subnet_id
    if subnet.map_public_ip_on_launch == false
  ]
  discovered_private_subnet_cidr_blocks = [
    for subnet_id, subnet in data.aws_subnet.cluster_subnets : subnet.cidr_block
    if subnet.map_public_ip_on_launch == false
  ]

  # Effective networking: explicit inputs take precedence over discovery.
  # try() keeps locals evaluable when neither is provided (e.g. enabled = false).
  vpc_id                     = try(coalesce(var.vpc_id, local.discovered_vpc_id), null)
  private_subnet_ids         = length(var.private_subnet_ids) > 0 ? var.private_subnet_ids : local.discovered_private_subnet_ids
  private_subnet_cidr_blocks = length(var.private_subnet_cidr_blocks) > 0 ? var.private_subnet_cidr_blocks : local.discovered_private_subnet_cidr_blocks

  replication_group_id = coalesce(
    var.elasticache.replication_group_id,
    substr(
      lower(replace(
        "${var.partner_name}-${var.environment}-redis",
        "/[^a-z0-9-]/", "-"
      )),
      0, 40 # ElastiCache replication group ID max length
    )
  )

  # Parameter group family: valkey7, valkey8, redis7, etc.
  engine_major_version   = floor(tonumber(var.elasticache.engine_version))
  parameter_group_family = "${var.elasticache.engine}${local.engine_major_version}"

  # Build one ingress rule per CIDR (upstream module uses aws_vpc_security_group_ingress_rule which requires cidr_ipv4)
  all_allowed_cidrs = concat(local.private_subnet_cidr_blocks, var.elasticache.additional_allowed_cidr_blocks)
  security_group_rules = {
    for idx, cidr in local.all_allowed_cidrs : "ingress_cidr_${idx}" => {
      cidr_ipv4   = cidr
      description = "Allow access on port ${var.elasticache.port} from ${cidr}"
    }
  }
}

# ***************************************
#  ElastiCache Replication Group
# ***************************************
module "elasticache" {
  count = var.elasticache.enabled ? 1 : 0

  source  = "terraform-aws-modules/elasticache/aws"
  version = "~> 1.0"

  replication_group_id = local.replication_group_id
  description          = "ElastiCache ${var.elasticache.engine} for ${var.partner_name}-${var.environment}"

  # Engine
  engine         = var.elasticache.engine
  engine_version = var.elasticache.engine_version

  # Instance
  node_type          = var.elasticache.node_type
  num_cache_clusters = var.elasticache.num_cache_clusters
  port               = var.elasticache.port

  # Data tiering
  data_tiering_enabled = var.elasticache.data_tiering_enabled

  # High availability
  multi_az_enabled           = var.elasticache.multi_az_enabled
  automatic_failover_enabled = var.elasticache.automatic_failover_enabled

  # Encryption
  at_rest_encryption_enabled = var.elasticache.at_rest_encryption_enabled
  transit_encryption_enabled = var.elasticache.transit_encryption_enabled

  # Auth (stored in state until AWS provider supports auth_token_wo)
  auth_token = var.elasticache.auth_token

  # Maintenance & backups
  maintenance_window       = var.elasticache.maintenance_window
  snapshot_retention_limit = var.elasticache.snapshot_retention_limit
  snapshot_window          = var.elasticache.snapshot_window

  # Parameter group
  create_parameter_group = true
  parameter_group_family = local.parameter_group_family
  parameter_group_name   = "${local.replication_group_id}-params"
  parameters             = var.elasticache.parameters

  # Subnet group
  create_subnet_group = true
  subnet_group_name   = "${local.replication_group_id}-subnets"
  subnet_ids          = local.private_subnet_ids

  # Security group (created by upstream module)
  create_security_group = true
  security_group_name   = "${local.replication_group_id}-sg"
  vpc_id                = local.vpc_id

  security_group_rules = local.security_group_rules

  # Disable CloudWatch log delivery to avoid mock provider issues in tests
  log_delivery_configuration = {}
}

# ***************************************
#  ExternalName service (optional)
#
#  Aliases the primary endpoint into the cluster; annotations can expose it
#  over Tailscale. Requires a configured kubernetes provider.
# ***************************************
resource "kubernetes_service" "externalname" {
  count = var.elasticache.enabled && var.externalname_service.enabled ? 1 : 0

  metadata {
    name        = var.externalname_service.name
    namespace   = var.externalname_service.namespace
    annotations = var.externalname_service.annotations
  }
  spec {
    type          = "ExternalName"
    external_name = module.elasticache[0].replication_group_primary_endpoint_address
  }
}
