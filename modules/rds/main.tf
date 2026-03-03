# ***************************************
#  Local variables
# ***************************************
locals {
  identifier = coalesce(
    var.rds.identifier_override,
    substr(
      lower(replace("${var.partner_name}-${var.environment}-${var.rds.db_name}", "/[^a-z0-9-]/", "-")),
      0, 63
    )
  )

  pg_major_version = floor(var.rds.engine_version)
}

# ***************************************
#  Security Group
# ***************************************
module "rds_security_group" {
  count = var.rds.enabled ? 1 : 0

  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.3.0"

  name        = local.identifier
  description = "Security group for ${local.identifier} RDS ${var.rds.engine} on port ${var.rds.port}"
  vpc_id      = var.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = var.rds.port
      to_port     = var.rds.port
      protocol    = "tcp"
      cidr_blocks = join(",", concat(var.rds.allowed_cidr_blocks, var.private_subnet_cidr_blocks))
    }
  ]

  tags = var.tags
}

# ***************************************
#  RDS Instance
# ***************************************
module "rds_instance" {
  count = var.rds.enabled ? 1 : 0

  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.10"

  identifier = local.identifier

  engine         = var.rds.engine
  engine_version = var.rds.engine_version
  family         = "${var.rds.engine}${local.pg_major_version}"

  instance_class        = var.rds.instance_class
  allocated_storage     = var.rds.allocated_storage
  max_allocated_storage = var.rds.max_allocated_storage
  multi_az              = var.rds.multi_az
  port                  = var.rds.port
  parameters            = var.rds.parameters

  db_name  = var.rds.db_name
  username = var.rds.username
  password = var.rds.password

  manage_master_user_password                            = var.rds.password == null
  manage_master_user_password_rotation                   = var.rds.enable_master_password_rotation
  master_user_password_rotation_automatically_after_days = var.rds.master_password_rotation_days

  iam_database_authentication_enabled = false

  maintenance_window      = var.rds.maintenance_window
  backup_retention_period = var.rds.backup_retention_period

  monitoring_interval    = var.rds.monitoring_interval
  create_monitoring_role = var.rds.create_monitoring_role
  monitoring_role_name   = var.rds.monitoring_role_name
  monitoring_role_arn    = var.rds.monitoring_role_arn

  create_db_subnet_group = true
  subnet_ids             = var.private_subnet_ids
  vpc_security_group_ids = [module.rds_security_group[0].security_group_id]

  deletion_protection = var.rds.deletion_protection
  tags                = var.tags
}