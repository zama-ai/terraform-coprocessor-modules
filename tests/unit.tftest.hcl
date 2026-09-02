mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = { partition = "aws", dns_suffix = "amazonaws.com" }
  }
  mock_data "aws_caller_identity" {
    defaults = {
      arn        = "arn:aws:iam::123456789012:user/test"
      account_id = "123456789012"
      user_id    = "AIDAXXXXXXXXXXXXXXXXX"
    }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_data "aws_iam_session_context" {
    defaults = {
      issuer_arn   = "arn:aws:iam::123456789012:role/test-role"
      issuer_id    = "AROAXXXXXXXXXXXXXXXXX"
      issuer_name  = "test-role"
      session_name = "test-session"
    }
  }

  # aws_db_instance.master_user_secret is indexed by the upstream module's
  # aws_secretsmanager_secret_rotation resource when
  # manage_master_user_password = true. The mock provider returns [] by default,
  # which fails on apply with "the collection has no elements". Needed by the
  # apply-mode runs below; modules/rds/tests/unit.tftest.hcl stubs it the same way.
  mock_resource "aws_db_instance" {
    defaults = {
      master_user_secret = [
        {
          kms_key_id    = ""
          secret_arn    = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:rds!db-test"
          secret_status = "active"
        }
      ]
    }
  }
}

mock_provider "kubernetes" {}

# Shared defaults across all runs.
# - networking.enabled = false with existing_vpc set — keeps the baseline simple
#   (no networking module, all VPC values come directly from variables).
# - eks.enabled = false — avoids needing EKS-specific mocks in simple tests.
variables {
  partner_name = "acme"
  environment  = "mainnet"
  aws_region   = "eu-west-1"

  networking = {
    vpc     = { cidr = "10.0.0.0/16", availability_zones = ["eu-west-1a", "eu-west-1b"] }
    enabled = false
    existing_vpc = {
      vpc_id             = "vpc-00000000000000000"
      private_subnet_ids = ["subnet-aaaaaaaaaaaaaaaa1", "subnet-aaaaaaaaaaaaaaaa2"]
    }
  }

  eks = { enabled = false }

  # var.s3 has a validation requiring at least one bucket, and no default that
  # satisfies it. Every run block inherits these shared variables, so without an
  # s3 entry here the whole file fails at variable validation before any plan.
  s3 = {
    buckets = {
      coprocessor = {}
    }
  }
}

# =============================================================================
# existing_vpc path
#
# When networking.enabled = false but existing_vpc is supplied, the networking
# module is skipped entirely and local.vpc_id falls through to the existing_vpc
# values. Because these are directly-configured variable values (not computed
# resource attributes) they are plan-time known and assertable.
# =============================================================================

run "existing_vpc_bypasses_networking_module" {
  command = plan

  assert {
    condition     = length(module.networking) == 0
    error_message = "Networking module must not be created when networking.enabled = false."
  }

  assert {
    condition     = output.vpc_id == "vpc-00000000000000000"
    error_message = "output.vpc_id must come from existing_vpc.vpc_id when networking is disabled."
  }
}

# =============================================================================
# additional_subnet_ids guard
#
# local.additional_subnet_ids is [] unless both:
#   - networking.enabled = true, AND
#   - networking.additional_subnets.enabled = true
# The output.additional_subnet_ids is a direct projection of this local, so
# it is plan-time knowable in both false-branch cases.
# =============================================================================

run "additional_subnet_ids_empty_when_networking_disabled" {
  command = plan

  assert {
    condition     = output.additional_subnet_ids == []
    error_message = "additional_subnet_ids must be [] when networking.enabled = false."
  }
}

run "additional_subnet_ids_empty_when_additional_subnets_disabled" {
  command = plan

  variables {
    networking = {
      vpc                = { cidr = "10.0.0.0/16", availability_zones = ["eu-west-1a", "eu-west-1b"] }
      enabled            = true
      additional_subnets = { enabled = false }
    }
  }

  assert {
    condition     = output.additional_subnet_ids == []
    error_message = "additional_subnet_ids must be [] when additional_subnets.enabled = false."
  }
}

# =============================================================================
#  EKS module count wiring
# =============================================================================

run "eks_disabled_creates_no_module" {
  command = plan

  # Uses shared defaults: eks.enabled = false.
  assert {
    condition     = length(module.eks) == 0
    error_message = "EKS module must not be created when eks.enabled = false."
  }
}

run "eks_enabled_creates_one_module" {
  command = plan

  variables {
    eks = { enabled = true }
  }

  assert {
    condition     = length(module.eks) == 1
    error_message = "EKS module must be created when eks.enabled = true."
  }
}

# =============================================================================
#  EKS-disabled outputs all null
#
# All EKS outputs are guarded with one(module.eks[*].*) which returns null when
# the module count is 0 — deterministic at plan time.
# =============================================================================

run "eks_disabled_outputs_all_null" {
  command = plan

  assert {
    condition     = output.eks_cluster_name == null
    error_message = "eks_cluster_name must be null when eks.enabled = false."
  }

  assert {
    condition     = output.eks_cluster_endpoint == null
    error_message = "eks_cluster_endpoint must be null when eks.enabled = false."
  }

  assert {
    condition     = output.eks_karpenter_iam_role_arn == null
    error_message = "eks_karpenter_iam_role_arn must be null when eks.enabled = false."
  }

  assert {
    condition     = output.eks_karpenter_queue_name == null
    error_message = "eks_karpenter_queue_name must be null when eks.enabled = false."
  }
}

# =============================================================================
#  Variable validation
# =============================================================================

run "rejects_invalid_vpc_cidr" {
  command = plan

  variables {
    networking = {
      vpc     = { cidr = "not-a-cidr", availability_zones = ["eu-west-1a"] }
      enabled = false
      existing_vpc = {
        vpc_id             = "vpc-00000000000000000"
        private_subnet_ids = ["subnet-aaaaaaaaaaaaaaaa1"]
      }
    }
  }

  expect_failures = [var.networking]
}

# =============================================================================
#  ElastiCache security contract
# =============================================================================

run "elasticache_secure_defaults_use_rediss" {
  command = plan

  variables {
    elasticache = {
      enabled = true
    }
  }

  assert {
    condition     = output.elasticache_connection_scheme == "rediss"
    error_message = "The root module must expose rediss for the secure ElastiCache defaults."
  }
}

run "elasticache_shadow_compatibility_uses_redis" {
  command = plan

  variables {
    elasticache = {
      enabled                    = true
      engine                     = "redis"
      engine_version             = "7.1"
      at_rest_encryption_enabled = true
      transit_encryption_enabled = false
    }
  }

  assert {
    condition     = output.elasticache_connection_scheme == "redis"
    error_message = "The root module must expose redis for the explicit plaintext shadow profile."
  }
}

run "elasticache_r6gd_requires_data_tiering" {
  command = plan

  variables {
    elasticache = {
      enabled              = true
      node_type            = "cache.r6gd.xlarge"
      data_tiering_enabled = false
    }
  }

  expect_failures = [var.elasticache]
}

run "elasticache_ha_requires_two_clusters" {
  command = plan

  variables {
    elasticache = {
      enabled                    = true
      num_cache_clusters         = 1
      multi_az_enabled           = true
      automatic_failover_enabled = true
    }
  }

  expect_failures = [var.elasticache]
}

run "elasticache_multi_az_requires_failover" {
  command = plan

  variables {
    elasticache = {
      enabled                    = true
      num_cache_clusters         = 3
      multi_az_enabled           = true
      automatic_failover_enabled = false
    }
  }

  expect_failures = [var.elasticache]
}

# =============================================================================
#  KMS module
# =============================================================================

run "kms_disabled_creates_no_resources" {
  command = plan

  # kms.enabled defaults to false — no KMS key/alias created.
  assert {
    condition     = output.kms_key_arn == null
    error_message = "kms_key_arn must be null when kms.enabled = false."
  }

  assert {
    condition     = output.kms_alias_name == null
    error_message = "kms_alias_name must be null when kms.enabled = false."
  }
}

run "kms_enabled_creates_key_with_expected_alias" {
  command = plan

  variables {
    kms = {
      enabled            = true
      consumer_role_arns = ["arn:aws:iam::555555555555:role/coprocessor-consumer"]
    }
  }

  assert {
    condition     = module.kms.alias_name == "alias/acme-mainnet-coprocessor-keypair"
    error_message = "kms alias must follow alias/<partner>-<environment>-coprocessor-keypair pattern."
  }
}

# =============================================================================
#  k8s Charts module count wiring
# =============================================================================

run "k8s_charts_disabled_creates_no_module" {
  command = plan

  # k8s_system_charts.enabled defaults to false — no helm releases created.
  assert {
    condition     = length(module.k8s_system_charts) == 0
    error_message = "k8s_system_charts module must not be created when k8s_system_charts.enabled = false."
  }
}

# =============================================================================
#  k8s module
# =============================================================================

run "k8s_enabled_plans_without_error" {
  command = plan

  variables {
    k8s_coprocessor_deps = {
      enabled           = true
      default_namespace = "coprocessor"
      namespaces = {
        coprocessor = {}
      }
    }
  }

  assert {
    condition     = module.k8s_coprocessor_deps.namespace == "coprocessor"
    error_message = "k8s_coprocessor_deps.namespace must match default_namespace when enabled = true."
  }
}

# =============================================================================
#  BYOC: kubernetes_provider.oidc_provider_arn takes precedence
#
# When a partner brings their own EKS cluster (eks.enabled = false) and supplies
# kubernetes_provider.oidc_provider_arn explicitly, the plan must succeed without
# errors (no coalesce(null, null) failure and no empty OIDC ARN silently used).
# =============================================================================

run "byoc_oidc_provider_arn_plans_without_error" {
  command = plan

  variables {
    kubernetes_provider = {
      host                   = "https://byoc.example.com"
      cluster_ca_certificate = "dGVzdA=="
      cluster_name           = "byoc-cluster"
      oidc_provider_arn      = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E"
    }
    k8s_coprocessor_deps = {
      enabled           = true
      default_namespace = "coprocessor"
    }
  }

  assert {
    condition     = length(module.eks) == 0
    error_message = "EKS module must not be created when eks.enabled = false."
  }

  assert {
    condition     = module.k8s_coprocessor_deps.namespace == "coprocessor"
    error_message = "k8s_coprocessor_deps must plan successfully with a BYOC OIDC provider ARN."
  }
}

# =============================================================================
#  Listener RDS
#
#  A second instance of modules/rds for the listener component. It gets its own
#  client SG and its own SecurityGroupPolicy pod label, so a pod reaches only
#  the database whose label it carries.
# =============================================================================

run "listener_rds_disabled_by_default" {
  command = plan

  # module "listener_rds" has no count at the root — gating is internal to the
  # module, matching module "rds" — so assert on the outputs rather than on
  # length(module.listener_rds).
  assert {
    condition     = output.listener_rds_db_instance_identifier == null
    error_message = "listener_rds_db_instance_identifier must be null when listener_rds is not configured."
  }

  assert {
    condition     = output.listener_rds_server_security_group_id == null
    error_message = "listener_rds_server_security_group_id must be null when listener_rds is not configured."
  }

  assert {
    condition     = output.listener_rds_master_secret_arn == null
    error_message = "listener_rds_master_secret_arn must be null when listener_rds is not configured."
  }

  assert {
    condition     = output.listener_rds_client_security_group_id == null
    error_message = "listener_rds_client_security_group_id must be null when listener_rds is not configured."
  }
}

# The isolation guarantee: each database has its own client SG and its own
# server SG. Uses apply so the mock provider materialises distinct SG IDs; at
# plan time both sides are unknown and the comparison would be indeterminate.
run "listener_rds_creates_a_dedicated_client_sg" {
  command = apply

  variables {
    rds = {
      enabled                = true
      db_name                = "coprocessor"
      monitoring_interval    = 0
      create_monitoring_role = false
    }
    listener_rds = {
      enabled                = true
      db_name                = "listener"
      monitoring_interval    = 0
      create_monitoring_role = false
    }
  }

  assert {
    condition     = output.listener_rds_client_security_group_id != output.rds_client_security_group_id
    error_message = "Each database must have its own client SG; sharing one would let any rds-client pod reach both databases."
  }

  assert {
    condition     = output.listener_rds_server_security_group_id != output.rds_server_security_group_id
    error_message = "Each database must have its own server SG."
  }

  assert {
    condition     = output.listener_rds_db_instance_identifier != output.rds_db_instance_identifier
    error_message = "The two instances must have distinct RDS identifiers."
  }

  assert {
    condition     = output.listener_rds_master_secret_arn != null && output.rds_master_secret_arn != null
    error_message = "Both instances must publish a master secret ARN when managed passwords are enabled."
  }
}

run "listener_rds_standalone_has_its_own_client_sg" {
  command = apply

  variables {
    eks = { enabled = false }

    rds = { enabled = false }
    listener_rds = {
      enabled                = true
      db_name                = "listener"
      monitoring_interval    = 0
      create_monitoring_role = false
    }
  }

  assert {
    condition     = output.rds_client_security_group_id == null
    error_message = "No coprocessor client SG must exist when rds.enabled = false."
  }

  assert {
    condition     = output.listener_rds_client_security_group_id != null
    error_message = "The listener must have its own client SG regardless of whether the coprocessor DB is enabled."
  }

  assert {
    condition     = output.listener_rds_server_security_group_id != null
    error_message = "The listener server SG must be created when listener_rds.enabled = true."
  }
}

# =============================================================================
#  EKS intra-cluster ingress, one pair of rules per database
# =============================================================================

run "eks_ingress_rules_created_per_enabled_database" {
  command = plan

  variables {
    eks = { enabled = true }

    rds = {
      enabled                = true
      db_name                = "coprocessor"
      monitoring_interval    = 0
      create_monitoring_role = false
    }
    listener_rds = {
      enabled                = true
      db_name                = "listener"
      monitoring_interval    = 0
      create_monitoring_role = false
    }
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.cluster_from_rds_client) == 2
    error_message = "One kube-apiserver ingress rule must be created per enabled database's client SG."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.node_from_rds_client) == 2
    error_message = "One node SG ingress rule must be created per enabled database's client SG."
  }

  assert {
    condition = alltrue([
      for k in ["coprocessor", "listener"] :
      contains(keys(aws_vpc_security_group_ingress_rule.cluster_from_rds_client), k)
    ])
    error_message = "Ingress rules must be keyed by database name (coprocessor, listener)."
  }
}

run "eks_ingress_rules_created_for_standalone_listener" {
  command = plan

  variables {
    eks = { enabled = true }

    rds = { enabled = false }
    listener_rds = {
      enabled                = true
      db_name                = "listener"
      monitoring_interval    = 0
      create_monitoring_role = false
    }
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.cluster_from_rds_client) == 1
    error_message = "kube-apiserver ingress must be created for the listener client SG when only the listener RDS is enabled."
  }

  assert {
    condition     = keys(aws_vpc_security_group_ingress_rule.cluster_from_rds_client) == ["listener"]
    error_message = "Only the listener ingress rule must exist when the coprocessor DB is disabled."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.node_from_rds_client) == 1
    error_message = "Node SG ingress must be created for the listener client SG when only the listener RDS is enabled."
  }
}

run "eks_ingress_rules_skipped_when_both_databases_disabled" {
  command = plan

  variables {
    eks          = { enabled = true }
    rds          = { enabled = false }
    listener_rds = { enabled = false }
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.cluster_from_rds_client) == 0
    error_message = "No client ingress rules must be created when both databases are disabled."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.node_from_rds_client) == 0
    error_message = "No client ingress rules must be created when both databases are disabled."
  }
}

# =============================================================================
#  Listener RDS naming validation
#
#  Security group names and the RDS identifier both derive from db_name, and SG
#  names are unique per VPC, so the two instances must not share a db_name.
# =============================================================================

run "listener_rds_rejects_db_name_matching_coprocessor" {
  command = plan

  variables {
    rds          = { enabled = true, db_name = "coprocessor" }
    listener_rds = { enabled = true, db_name = "coprocessor" }
  }

  expect_failures = [var.listener_rds]
}

run "listener_rds_rejects_null_db_name" {
  command = plan

  variables {
    listener_rds = { enabled = true }
  }

  expect_failures = [var.listener_rds]
}
