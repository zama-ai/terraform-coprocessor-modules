# ***************************************
#  Local variables
# ***************************************
locals {
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
  all_allowed_cidrs = concat(var.private_subnet_cidr_blocks, var.elasticache.additional_allowed_cidr_blocks)
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
  subnet_ids          = var.private_subnet_ids

  # Security group (created by upstream module)
  create_security_group = true
  security_group_name   = "${local.replication_group_id}-sg"
  vpc_id                = var.vpc_id

  security_group_rules = local.security_group_rules

  # Disable CloudWatch log delivery to avoid mock provider issues in tests
  log_delivery_configuration = {}
}
