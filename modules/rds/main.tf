# ***************************************
#  Local variables
# ***************************************
locals {
  identifier = coalesce(
    var.rds.identifier_override,
    substr(
      lower(replace(
        join("-", compact([var.partner_name, var.environment, var.rds.db_name])),
        "/[^a-z0-9-]/", "-"
      )),
      0, 63
    )
  )

  pg_major_version = floor(tonumber(var.rds.engine_version))

  # Upstream terraform-aws-modules/rds requires a non-null monitoring_role_name
  # when create_monitoring_role = true. Compute a stable default when not overridden.
  monitoring_role_name = coalesce(var.rds.monitoring_role_name, "${local.identifier}-monitoring")
}

# ***************************************
#  Security Group
# ***************************************
module "rds_security_group" {
  count = var.rds.enabled ? 1 : 0

  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.3.0"

  name        = coalesce(var.rds.db_name, "rds-sg")
  description = "Security group for ${coalesce(var.rds.db_name, "rds-sg")} RDS ${var.rds.engine} on port ${var.rds.port}"
  vpc_id      = var.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = var.rds.port
      to_port     = var.rds.port
      protocol    = "tcp"
      cidr_blocks = join(",", concat(var.rds.additional_allowed_cidr_blocks, var.private_subnet_cidr_blocks))
    }
  ]
}

# ***************************************
#  RDS Instance
# ***************************************
module "rds_instance" {
  count = var.rds.enabled ? 1 : 0

  source  = "terraform-aws-modules/rds/aws"
  version = "~> 7.1"

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

  manage_master_user_password                            = var.rds.manage_master_user_password
  password_wo                                            = var.rds.manage_master_user_password ? null : var.rds.password_wo
  password_wo_version                                    = var.rds.manage_master_user_password ? null : var.rds.password_wo_version
  manage_master_user_password_rotation                   = var.rds.manage_master_user_password && var.rds.enable_master_password_rotation
  master_user_password_rotation_automatically_after_days = var.rds.master_password_rotation_days

  iam_database_authentication_enabled = var.rds.iam_database_authentication_enabled

  maintenance_window      = var.rds.maintenance_window
  backup_retention_period = var.rds.backup_retention_period

  monitoring_interval    = var.rds.monitoring_interval
  create_monitoring_role = var.rds.create_monitoring_role
  monitoring_role_name   = local.monitoring_role_name
  monitoring_role_arn    = var.rds.monitoring_role_arn

  create_db_subnet_group = true
  subnet_ids             = var.private_subnet_ids
  vpc_security_group_ids = [module.rds_security_group[0].security_group_id]

  deletion_protection = var.rds.deletion_protection
}
