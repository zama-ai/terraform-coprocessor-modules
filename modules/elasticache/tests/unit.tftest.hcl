mock_provider "aws" {}

mock_provider "kubernetes" {}

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
    condition     = output.connection_scheme == null
    error_message = "connection_scheme must be null when elasticache.enabled = false."
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

  assert {
    condition     = output.connection_scheme == "rediss"
    error_message = "Secure defaults must expose the rediss connection scheme."
  }
}

# =============================================================================
#  Security contract and temporary shadow compatibility
# =============================================================================

run "secure_defaults_require_tls_and_at_rest_encryption" {
  command = plan

  variables {
    elasticache = {
      enabled = true
    }
  }

  assert {
    condition     = var.elasticache.at_rest_encryption_enabled
    error_message = "At-rest encryption must be enabled by default."
  }

  assert {
    condition     = var.elasticache.transit_encryption_enabled
    error_message = "Transit encryption must be enabled by default."
  }
}

run "plaintext_shadow_profile_is_explicit_and_unauthenticated" {
  command = apply

  variables {
    elasticache = {
      enabled                        = true
      engine                         = "redis"
      engine_version                 = "7.1"
      at_rest_encryption_enabled     = true
      transit_encryption_enabled     = false
      snapshot_retention_limit       = 7
      additional_allowed_cidr_blocks = []
    }
  }

  assert {
    condition     = output.connection_scheme == "redis"
    error_message = "The temporary plaintext shadow profile must expose the redis connection scheme."
  }

  assert {
    condition     = var.elasticache.at_rest_encryption_enabled
    error_message = "The temporary shadow profile must retain at-rest encryption."
  }
}

# =============================================================================
#  Data tiering with r6gd (data-tiered sizing example)
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

run "r6gd_without_data_tiering_fails_validation" {
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

# =============================================================================
#  No data tiering — in-memory sizing example
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

run "multi_az_without_failover_fails_validation" {
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

run "single_cluster_without_ha_plans_without_error" {
  command = plan

  variables {
    elasticache = {
      enabled                    = true
      num_cache_clusters         = 1
      multi_az_enabled           = false
      automatic_failover_enabled = false
    }
  }

  assert {
    condition     = length(module.elasticache) == 1
    error_message = "A single cache cluster must be allowed when Multi-AZ and automatic failover are both disabled."
  }
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

# =============================================================================
#  EKS discovery (cluster_name set, explicit networking omitted)
# =============================================================================

run "cluster_name_discovers_networking" {
  command = plan

  variables {
    cluster_name               = "disc-cluster"
    vpc_id                     = null
    private_subnet_ids         = []
    private_subnet_cidr_blocks = []
    elasticache                = { enabled = true }
  }

  override_data {
    target = data.aws_eks_cluster.cluster[0]
    values = {
      vpc_config = [{
        vpc_id     = "vpc-discovered000001"
        subnet_ids = ["subnet-disc-a", "subnet-disc-b"]
      }]
    }
  }

  override_data {
    target = data.aws_subnet.cluster_subnets["subnet-disc-a"]
    values = {
      map_public_ip_on_launch = false
      cidr_block              = "10.9.0.0/24"
    }
  }

  override_data {
    target = data.aws_subnet.cluster_subnets["subnet-disc-b"]
    values = {
      map_public_ip_on_launch = false
      cidr_block              = "10.9.1.0/24"
    }
  }

  assert {
    condition     = output.vpc_id == "vpc-discovered000001"
    error_message = "vpc_id must be discovered from the EKS cluster when cluster_name is set."
  }

  assert {
    condition     = length(module.elasticache) == 1
    error_message = "ElastiCache module must be created when networking is discovered from cluster_name."
  }
}

run "discovery_excludes_public_subnets" {
  command = plan

  variables {
    cluster_name               = "disc-cluster"
    vpc_id                     = null
    private_subnet_ids         = []
    private_subnet_cidr_blocks = []
    elasticache                = { enabled = true }
  }

  override_data {
    target = data.aws_eks_cluster.cluster[0]
    values = {
      vpc_config = [{
        vpc_id     = "vpc-mixed0000000001"
        subnet_ids = ["subnet-priv-1", "subnet-priv-2", "subnet-pub-1"]
      }]
    }
  }

  override_data {
    target = data.aws_subnet.cluster_subnets["subnet-priv-1"]
    values = { map_public_ip_on_launch = false, cidr_block = "10.1.0.0/24" }
  }
  override_data {
    target = data.aws_subnet.cluster_subnets["subnet-priv-2"]
    values = { map_public_ip_on_launch = false, cidr_block = "10.1.1.0/24" }
  }
  override_data {
    target = data.aws_subnet.cluster_subnets["subnet-pub-1"]
    values = { map_public_ip_on_launch = true, cidr_block = "10.1.2.0/24" }
  }

  assert {
    condition     = length(output.private_subnet_ids) == 2
    error_message = "Public subnets (map_public_ip_on_launch = true) must be excluded from discovered private subnets."
  }

  assert {
    condition     = !contains(output.private_subnet_ids, "subnet-pub-1")
    error_message = "The public subnet must not appear in the discovered private subnet list."
  }
}

run "additional_workload_cidrs_are_merged_into_ingress" {
  command = plan

  variables {
    elasticache = {
      enabled                        = true
      additional_allowed_cidr_blocks = ["10.20.0.0/20"]
    }
  }

  assert {
    condition     = contains(local.all_allowed_cidrs, "10.0.0.0/24") && contains(local.all_allowed_cidrs, "10.20.0.0/20")
    error_message = "ElastiCache ingress must include both private subnet CIDRs and explicitly supplied workload CIDRs."
  }
}

run "auth_token_without_transit_encryption_fails_validation" {
  command = plan

  variables {
    elasticache = {
      enabled                    = true
      transit_encryption_enabled = false
      auth_token                 = "some-secret-token-value"
    }
  }

  expect_failures = [var.elasticache]
}

run "disabled_without_networking_does_not_error" {
  command = plan

  variables {
    cluster_name               = null
    vpc_id                     = null
    private_subnet_ids         = []
    private_subnet_cidr_blocks = []
    elasticache                = { enabled = false }
  }

  assert {
    condition     = output.vpc_id == null
    error_message = "vpc_id must resolve to null (not error) when disabled with no networking inputs."
  }
}

run "explicit_vpc_overrides_discovery" {
  command = plan

  variables {
    cluster_name = "disc-cluster"
    # vpc_id / subnets inherited from shared defaults (explicit) — must win
    elasticache = { enabled = true }
  }

  override_data {
    target = data.aws_eks_cluster.cluster[0]
    values = {
      vpc_config = [{
        vpc_id     = "vpc-discovered000001"
        subnet_ids = []
      }]
    }
  }

  assert {
    condition     = output.vpc_id == "vpc-00000000000000000"
    error_message = "Explicit vpc_id must take precedence over the value discovered from cluster_name."
  }
}

# =============================================================================
#  Kubernetes ExternalName Service
# =============================================================================

run "k8s_service_disabled_by_default" {
  command = plan

  variables {
    elasticache = { enabled = true }
  }

  assert {
    condition     = length(kubernetes_service.external_name) == 0
    error_message = "No ExternalName Service must be created when elasticache.k8s_service is omitted."
  }

  assert {
    condition     = output.k8s_service_fqdns == {}
    error_message = "k8s_service_fqdns must be an empty map when the ExternalName Service is disabled."
  }
}

run "k8s_service_not_created_when_elasticache_disabled" {
  command = plan

  variables {
    elasticache = {
      enabled     = false
      k8s_service = { enabled = false, namespaces = ["coproc"] }
    }
  }

  assert {
    condition     = length(kubernetes_service.external_name) == 0
    error_message = "No ExternalName Service must be created when elasticache.enabled = false."
  }
}

run "k8s_service_creates_one_service_per_namespace" {
  command = plan

  variables {
    elasticache = {
      enabled = true
      k8s_service = {
        enabled    = true
        namespaces = ["coproc", "eth-blockchain", "gw-blockchain"]
      }
    }
  }

  assert {
    condition     = length(kubernetes_service.external_name) == 3
    error_message = "One ExternalName Service must be created per entry in k8s_service.namespaces."
  }

  assert {
    condition     = toset(keys(kubernetes_service.external_name)) == toset(["coproc", "eth-blockchain", "gw-blockchain"])
    error_message = "ExternalName Services must be keyed by namespace so adding a namespace never re-creates the others."
  }

  assert {
    condition     = kubernetes_service.external_name["eth-blockchain"].metadata[0].namespace == "eth-blockchain"
    error_message = "Each ExternalName Service must land in the namespace it is keyed by."
  }

  assert {
    condition     = output.k8s_service_fqdns["gw-blockchain"] == "redis.gw-blockchain.svc.cluster.local"
    error_message = "k8s_service_fqdns must expose the in-cluster DNS name of every created Service."
  }
}

run "k8s_service_defaults_to_redis_in_coproc" {
  command = plan

  variables {
    elasticache = {
      enabled     = true
      k8s_service = { enabled = true }
    }
  }

  assert {
    condition     = length(kubernetes_service.external_name) == 1
    error_message = "k8s_service must default to a single namespace."
  }

  assert {
    condition     = kubernetes_service.external_name["coproc"].metadata[0].name == "redis"
    error_message = "The ExternalName Service must default to the name \"redis\"."
  }

  assert {
    condition     = kubernetes_service.external_name["coproc"].spec[0].type == "ExternalName"
    error_message = "The Service type must be ExternalName."
  }
}

run "k8s_service_propagates_annotations_and_labels" {
  command = plan

  variables {
    elasticache = {
      enabled = true
      k8s_service = {
        enabled     = true
        name        = "listener-broker"
        namespaces  = ["eth-blockchain"]
        annotations = { "argocd.argoproj.io/sync-options" = "Prune=false" }
        labels      = { "app.kubernetes.io/component" = "cache" }
      }
    }
  }

  assert {
    condition = kubernetes_service.external_name["eth-blockchain"].metadata[0].annotations == tomap({
      "argocd.argoproj.io/sync-options" = "Prune=false"
    })
    error_message = "Annotations must be passed through verbatim, with no injected baseline keys."
  }

  assert {
    condition = kubernetes_service.external_name["eth-blockchain"].metadata[0].labels == tomap({
      "app.kubernetes.io/component" = "cache"
    })
    error_message = "Labels must be passed through verbatim."
  }

  assert {
    condition     = kubernetes_service.external_name["eth-blockchain"].metadata[0].name == "listener-broker"
    error_message = "k8s_service.name must override the default Service name."
  }
}

run "k8s_service_targets_the_primary_endpoint" {
  command = apply

  variables {
    elasticache = {
      enabled     = true
      k8s_service = { enabled = true }
    }
  }

  assert {
    condition     = kubernetes_service.external_name["coproc"].spec[0].external_name == split(":", module.elasticache[0].replication_group_primary_endpoint_address)[0]
    error_message = "The ExternalName Service must point at the replication group primary endpoint hostname, without a port suffix."
  }
}

run "k8s_service_enabled_without_elasticache_fails_validation" {
  command = plan

  variables {
    elasticache = {
      enabled     = false
      k8s_service = { enabled = true }
    }
  }

  expect_failures = [var.elasticache]
}

run "k8s_service_with_empty_namespaces_fails_validation" {
  command = plan

  variables {
    elasticache = {
      enabled     = true
      k8s_service = { enabled = true, namespaces = [] }
    }
  }

  expect_failures = [var.elasticache]
}
