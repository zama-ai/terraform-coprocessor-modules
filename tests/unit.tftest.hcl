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
}

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
      vpc_id                     = "vpc-00000000000000000"
      private_subnet_ids         = ["subnet-aaaaaaaaaaaaaaaa1", "subnet-aaaaaaaaaaaaaaaa2"]
      private_subnet_cidr_blocks = ["10.0.0.0/20", "10.0.16.0/20"]
    }
  }

  eks = { enabled = false }
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
#  Networking module count wiring
# =============================================================================

run "networking_enabled_creates_one_module" {
  command = plan

  variables {
    networking = {
      vpc     = { cidr = "10.0.0.0/16", availability_zones = ["eu-west-1a", "eu-west-1b"] }
      enabled = true
    }
  }

  assert {
    condition     = length(module.networking) == 1
    error_message = "Networking module must be created when networking.enabled = true."
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
        vpc_id                     = "vpc-00000000000000000"
        private_subnet_ids         = ["subnet-aaaaaaaaaaaaaaaa1"]
        private_subnet_cidr_blocks = ["10.0.0.0/20"]
      }
    }
  }

  expect_failures = [var.networking]
}

# =============================================================================
#  coalesce(null, null) regression — eks disabled, no kubernetes credentials
#
# Before the fix, versions.tf used coalesce() for the kubernetes provider locals.
# With eks.enabled = false and no kubernetes.host set, both arguments are null
# and coalesce() errors. The fix uses conditionals instead.
# =============================================================================

run "eks_disabled_without_kubernetes_credentials_plans_without_error" {
  command = plan

  # No kubernetes variable override — uses the default (all nulls).
  # eks.enabled = false from shared variables.
  assert {
    condition     = length(module.eks) == 0
    error_message = "EKS module must not be created when eks.enabled = false."
  }
}

# =============================================================================
#  k8s Charts module count wiring
# =============================================================================

run "k8s_charts_disabled_creates_no_module" {
  command = plan

  # k8s_charts.enabled defaults to false — no helm releases created.
  assert {
    condition     = length(module.k8s_charts) == 0
    error_message = "k8s_charts module must not be created when k8s_charts.enabled = false."
  }
}

run "k8s_charts_enabled_creates_one_module" {
  command = plan

  variables {
    k8s_charts = {
      enabled = true
      applications = {
        metrics-server = {
          namespace  = { name = "kube-system" }
          helm_chart = { repository = "https://kubernetes-sigs.github.io/metrics-server/", chart = "metrics-server", version = "3.12.0" }
        }
      }
    }
  }

  assert {
    condition     = length(module.k8s_charts) == 1
    error_message = "k8s_charts module must be created when k8s_charts.enabled = true."
  }
}

# =============================================================================
#  k8s module
# =============================================================================

run "k8s_enabled_plans_without_error" {
  command = plan

  variables {
    k8s = {
      enabled           = true
      default_namespace = "coprocessor"
      namespaces = {
        coprocessor = {}
      }
    }
  }

  assert {
    condition     = module.k8s.namespace == "coprocessor"
    error_message = "k8s.namespace must match default_namespace when k8s.enabled = true."
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
    k8s = {
      enabled           = true
      default_namespace = "coprocessor"
    }
  }

  assert {
    condition     = length(module.eks) == 0
    error_message = "EKS module must not be created when eks.enabled = false."
  }

  assert {
    condition     = module.k8s.namespace == "coprocessor"
    error_message = "k8s module must plan successfully with a BYOC OIDC provider ARN."
  }
}
