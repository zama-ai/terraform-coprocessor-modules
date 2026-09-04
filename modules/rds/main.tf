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
#  Security Groups
#
#  - rds_client: empty SG attached to pods via SecurityGroupPolicy in
#    k8s-coprocessor-deps. Pod-level source for the ingress below; inert on
#    instance types that don't support EKS Security Groups for Pods (e.g.
#    hpc7a).
#  - rds_server: attached to the RDS instance. Ingress on the DB port from
#    (1) rds_client, (2) private_subnet_cidr_blocks (subnet-level fallback),
#    (3) rds.additional_allowed_cidr_blocks (break-glass).
# ***************************************
resource "aws_security_group" "rds_client" {
  count = var.rds.enabled ? 1 : 0

  name        = "${coalesce(var.rds.db_name, "rds")}-client"
  description = "Pod-side SG for ${coalesce(var.rds.db_name, "rds")} RDS clients (attached to pods via SecurityGroupPolicy)"
  vpc_id      = var.vpc_id
}

resource "aws_security_group" "rds_server" {
  count = var.rds.enabled ? 1 : 0

  name        = "${coalesce(var.rds.db_name, "rds")}-server"
  description = "DB-side SG for ${coalesce(var.rds.db_name, "rds")} RDS ${var.rds.engine} on port ${var.rds.port}"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "rds_server_from_client" {
  count = var.rds.enabled ? 1 : 0

  security_group_id            = aws_security_group.rds_server[0].id
  referenced_security_group_id = aws_security_group.rds_client[0].id
  ip_protocol                  = "tcp"
  from_port                    = var.rds.port
  to_port                      = var.rds.port
  description                  = "Allow ${var.rds.engine} traffic from pods carrying the rds-client SG"
}

resource "aws_vpc_security_group_ingress_rule" "rds_server_from_private_subnets" {
  for_each = var.rds.enabled ? toset(var.private_subnet_cidr_blocks) : toset([])

  security_group_id = aws_security_group.rds_server[0].id
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = var.rds.port
  to_port           = var.rds.port
  description       = "Allow ${var.rds.engine} traffic from private subnet ${each.value}"
}

resource "aws_vpc_security_group_ingress_rule" "rds_server_from_extra_cidrs" {
  for_each = var.rds.enabled ? toset(var.rds.additional_allowed_cidr_blocks) : toset([])

  security_group_id = aws_security_group.rds_server[0].id
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = var.rds.port
  to_port           = var.rds.port
  description       = "Allow ${var.rds.engine} traffic from break-glass CIDR ${each.value}"
}

resource "aws_vpc_security_group_egress_rule" "rds_client_allow_all" {
  count = var.rds.enabled ? 1 : 0

  security_group_id = aws_security_group.rds_client[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all egress from pods carrying the rds-client SG"
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
  monitoring_role_arn    = var.rds.existing_monitoring_role_arn

  performance_insights_enabled          = var.rds.performance_insights_enabled
  performance_insights_retention_period = var.rds.performance_insights_retention_period
  performance_insights_kms_key_id       = var.rds.performance_insights_kms_key_id
  database_insights_mode                = var.rds.database_insights_mode

  create_db_subnet_group = true
  subnet_ids             = var.private_subnet_ids
  vpc_security_group_ids = [aws_security_group.rds_server[0].id]

  deletion_protection = var.rds.deletion_protection
}
