mock_provider "aws" {}

# Shared defaults across all runs.
variables {
  partner_name               = "acme"
  environment                = "mainnet"
  vpc_id                     = "vpc-00000000000000000"
  private_subnet_ids         = ["subnet-aaaaaaaaaaaaaaaa1", "subnet-aaaaaaaaaaaaaaaa2"]
  private_subnet_cidr_blocks = ["10.0.0.0/24", "10.0.1.0/24"]
}

# =============================================================================
#  enabled = false
# =============================================================================

run "disabled_creates_no_child_modules" {
  command = plan

  variables {
    elasticache = { enabled = false }
  }

  assert {
    condition     = length(module.elasticache) == 0
    error_message = "ElastiCache module must not be created when elasticache.enabled = false."
  }
}

run "disabled_outputs_all_null" {
  command = apply

  variables {
    elasticache = { enabled = false }
  }

  assert {
    condition     = output.replication_group_id == null
    error_message = "replication_group_id must be null when elasticache.enabled = false."
  }

  assert {
    condition     = output.replication_group_arn == null
    error_message = "replication_group_arn must be null when elasticache.enabled = false."
  }

  assert {
    condition     = output.primary_endpoint_address == null
    error_message = "primary_endpoint_address must be null when elasticache.enabled = false."
  }

  assert {
    condition     = output.reader_endpoint_address == null
    error_message = "reader_endpoint_address must be null when elasticache.enabled = false."
  }

  assert {
    condition     = output.port == null
    error_message = "port must be null when elasticache.enabled = false."
  }

  assert {
    condition     = output.security_group_id == null
    error_message = "security_group_id must be null when elasticache.enabled = false."
  }
}

# =============================================================================
#  enabled = true (testnet profile — no data tiering)
# =============================================================================

run "enabled_creates_elasticache_module" {
  command = plan

  variables {
    elasticache = {
      enabled = true
    }
  }

  assert {
    condition     = length(module.elasticache) == 1
    error_message = "ElastiCache module must be created when elasticache.enabled = true."
  }
}

run "enabled_outputs_all_non_null" {
  command = apply

  variables {
    elasticache = {
      enabled = true
    }
  }

  assert {
    condition     = output.replication_group_id != null
    error_message = "replication_group_id must be non-null when elasticache.enabled = true."
  }

  assert {
    condition     = output.replication_group_arn != null
    error_message = "replication_group_arn must be non-null when elasticache.enabled = true."
  }

  assert {
    condition     = output.security_group_id != null
    error_message = "security_group_id must be non-null when elasticache.enabled = true."
  }
}

# =============================================================================
#  Data tiering with r6gd (mainnet profile)
# =============================================================================

run "data_tiering_with_r6gd_plans_without_error" {
  command = plan

  variables {
    elasticache = {
      enabled              = true
      node_type            = "cache.r6gd.xlarge"
      data_tiering_enabled = true
    }
  }

  assert {
    condition     = length(module.elasticache) == 1
    error_message = "ElastiCache module must be created with data tiering on r6gd instance."
  }
}

# =============================================================================
#  Data tiering validation — non-r6gd must fail
# =============================================================================

run "data_tiering_with_non_r6gd_fails_validation" {
  command = plan

  variables {
    elasticache = {
      enabled              = true
      node_type            = "cache.r7g.large"
      data_tiering_enabled = true
    }
  }

  expect_failures = [var.elasticache]
}

# =============================================================================
#  No data tiering — testnet profile
# =============================================================================

run "no_data_tiering_with_r7g_plans_without_error" {
  command = plan

  variables {
    elasticache = {
      enabled              = true
      node_type            = "cache.r7g.large"
      data_tiering_enabled = false
    }
  }

  assert {
    condition     = length(module.elasticache) == 1
    error_message = "ElastiCache module must be created with r7g.large and no data tiering."
  }
}

# =============================================================================
#  HA configuration
# =============================================================================

run "ha_with_three_clusters_plans_without_error" {
  command = plan

  variables {
    elasticache = {
      enabled                    = true
      num_cache_clusters         = 3
      multi_az_enabled           = true
      automatic_failover_enabled = true
    }
  }

  assert {
    condition     = length(module.elasticache) == 1
    error_message = "ElastiCache module must be created with HA configuration."
  }
}

# =============================================================================
#  Failover validation — num_cache_clusters < 2 must fail
# =============================================================================

run "failover_with_single_cluster_fails_validation" {
  command = plan

  variables {
    elasticache = {
      enabled                    = true
      num_cache_clusters         = 1
      automatic_failover_enabled = true
    }
  }

  expect_failures = [var.elasticache]
}

# =============================================================================
#  Identifier override
# =============================================================================

run "identifier_override_is_accepted" {
  command = plan

  variables {
    elasticache = {
      enabled              = true
      replication_group_id = "custom-redis-id"
    }
  }

  assert {
    condition     = length(module.elasticache) == 1
    error_message = "ElastiCache module must be created when replication_group_id override is set."
  }
}

# =============================================================================
#  Custom engine version
# =============================================================================

run "custom_engine_version_plans_without_error" {
  command = plan

  variables {
    elasticache = {
      enabled        = true
      engine         = "valkey"
      engine_version = "8.0"
    }
  }

  assert {
    condition     = length(module.elasticache) == 1
    error_message = "ElastiCache module must be planned with custom engine version."
  }
}
