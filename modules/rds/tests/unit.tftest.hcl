mock_provider "aws" {
  # aws_db_instance.master_user_secret is needed by aws_secretsmanager_secret_rotation
  # when manage_master_user_password = true. The mock provider returns [] by default,
  # which causes an index error. Provide a stub so rotation resource can resolve secret_id.
  mock_resource "aws_db_instance" {
    defaults = {
      master_user_secret = [
        {
          kms_key_id    = ""
          secret_arn    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:rds!db-test"
          secret_status = "active"
        }
      ]
    }
  }
}

# Shared defaults across all runs.
# vpc_id and subnets are required by the security group and subnet group
# resources inside the child modules.
variables {
  partner_name               = "acme"
  environment                = "mainnet"
  vpc_id                     = "vpc-00000000000000000"
  private_subnet_ids         = ["subnet-aaaaaaaaaaaaaaaa1", "subnet-aaaaaaaaaaaaaaaa2"]
  private_subnet_cidr_blocks = ["10.0.0.0/24", "10.0.1.0/24"]
}

# All enabled runs must include monitoring_interval = 0 and
# create_monitoring_role = false to avoid the upstream module attempting to
# create an IAM role whose assume_role_policy is rendered from a data source
# that the mock provider returns invalid JSON for.

# =============================================================================
#  enabled = false
# =============================================================================

run "disabled_creates_no_child_modules" {
  command = plan

  variables {
    rds = { enabled = false }
  }

  assert {
    condition     = length(module.rds_security_group) == 0
    error_message = "Security group module must not be created when rds.enabled = false."
  }

  assert {
    condition     = length(module.rds_instance) == 0
    error_message = "RDS instance module must not be created when rds.enabled = false."
  }
}

# Outputs reference child module attributes (known after apply), so we use
# apply here. The mock provider supplies mock values; we assert null vs non-null.
run "disabled_outputs_all_null" {
  command = apply

  variables {
    rds = { enabled = false }
  }

  assert {
    condition     = output.db_instance_identifier == null
    error_message = "db_instance_identifier must be null when rds.enabled = false."
  }

  assert {
    condition     = output.db_instance_arn == null
    error_message = "db_instance_arn must be null when rds.enabled = false."
  }

  assert {
    condition     = output.db_instance_endpoint == null
    error_message = "db_instance_endpoint must be null when rds.enabled = false."
  }

  assert {
    condition     = output.db_instance_address == null
    error_message = "db_instance_address must be null when rds.enabled = false."
  }

  assert {
    condition     = output.db_instance_port == null
    error_message = "db_instance_port must be null when rds.enabled = false."
  }

  assert {
    condition     = output.db_instance_name == null
    error_message = "db_instance_name must be null when rds.enabled = false."
  }

  assert {
    condition     = output.security_group_id == null
    error_message = "security_group_id must be null when rds.enabled = false."
  }
}

# =============================================================================
#  enabled = true
# =============================================================================

run "enabled_creates_both_child_modules" {
  command = plan

  variables {
    rds = {
      enabled                = true
      db_name                = "coprocessor"
      monitoring_interval    = 0
      create_monitoring_role = false
    }
  }

  assert {
    condition     = length(module.rds_security_group) == 1
    error_message = "Security group module must be created when rds.enabled = true."
  }

  assert {
    condition     = length(module.rds_instance) == 1
    error_message = "RDS instance module must be created when rds.enabled = true."
  }
}

# =============================================================================
#  identifier logic
#
# local.identifier = coalesce(
#   var.rds.identifier_override,
#   substr(lower(replace(join("-", compact([partner, env, db_name])), ...)), 0, 63)
# )
# =============================================================================

run "identifier_override_is_accepted" {
  command = plan

  variables {
    rds = {
      enabled                = true
      db_name                = "coprocessor"
      identifier_override    = "zama-mainnet-coprocessor"
      monitoring_interval    = 0
      create_monitoring_role = false
    }
  }

  assert {
    condition     = length(module.rds_instance) == 1
    error_message = "RDS instance module must be created when identifier_override is set."
  }
}

# =============================================================================
#  Password / Secrets Manager
#
# manage_master_user_password = var.rds.password == null
# =============================================================================

run "secrets_manager_managed_password_plans_without_error" {
  command = plan

  variables {
    rds = {
      enabled                     = true
      db_name                     = "coprocessor"
      manage_master_user_password = true
      monitoring_interval         = 0
      create_monitoring_role      = false
    }
  }

  assert {
    condition     = length(module.rds_instance) == 1
    error_message = "RDS instance must be planned when manage_master_user_password = true (Secrets Manager managed)."
  }
}

run "explicit_password_wo_plans_without_error" {
  command = plan

  variables {
    rds = {
      enabled                     = true
      db_name                     = "coprocessor"
      manage_master_user_password = false
      password_wo                 = "supersecret"
      monitoring_interval         = 0
      create_monitoring_role      = false
    }
  }

  assert {
    condition     = length(module.rds_instance) == 1
    error_message = "RDS instance must be planned when an explicit password_wo is provided."
  }
}

# =============================================================================
#  Engine family computation
#
# local.pg_major_version = floor(tonumber(var.rds.engine_version))
# family = "${engine}${pg_major_version}"
#
# e.g. "17.4" → 17 → "postgres17"
#      "16"   → 16 → "postgres16"
# =============================================================================

run "patch_engine_version_plans_without_error" {
  command = plan

  variables {
    rds = {
      enabled                = true
      db_name                = "coprocessor"
      engine_version         = "17.4"
      monitoring_interval    = 0
      create_monitoring_role = false
    }
  }

  assert {
    condition     = length(module.rds_instance) == 1
    error_message = "RDS instance must be planned for a patch-level engine_version like '17.4'."
  }
}

run "major_engine_version_plans_without_error" {
  command = plan

  variables {
    rds = {
      enabled                = true
      db_name                = "coprocessor"
      engine_version         = "16"
      monitoring_interval    = 0
      create_monitoring_role = false
    }
  }

  assert {
    condition     = length(module.rds_instance) == 1
    error_message = "RDS instance must be planned for a major-only engine_version like '16'."
  }
}

# =============================================================================
#  IAM database authentication
# =============================================================================

run "iam_database_authentication_enabled_by_default" {
  command = plan

  variables {
    rds = {
      enabled                = true
      db_name                = "coprocessor"
      monitoring_interval    = 0
      create_monitoring_role = false
    }
  }

  assert {
    condition     = length(module.rds_instance) == 1
    error_message = "RDS instance must be planned with iam_database_authentication_enabled = true (default)."
  }
}

# =============================================================================
#  Password rotation
# =============================================================================

run "password_rotation_skipped_when_explicit_password_set" {
  command = plan

  variables {
    rds = {
      enabled                     = true
      db_name                     = "coprocessor"
      manage_master_user_password = false
      password_wo                 = "supersecret"
      monitoring_interval         = 0
      create_monitoring_role      = false
    }
  }

  assert {
    condition     = length(module.rds_instance) == 1
    error_message = "RDS instance must plan without rotation when an explicit password_wo is provided."
  }
}
