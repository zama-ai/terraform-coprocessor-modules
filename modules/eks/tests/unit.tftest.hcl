mock_provider "aws" {

  # aws_partition.partition is used in policy ARNs — must be a real partition string.
  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }

  # aws_caller_identity.arn must look like a real ARN — it is fed into
  # data.aws_iam_session_context which validates the ARN format at plan time.
  mock_data "aws_caller_identity" {
    defaults = {
      arn        = "arn:aws:iam::123456789012:user/test"
      account_id = "123456789012"
      user_id    = "AIDAXXXXXXXXXXXXXXXXX"
    }
  }

  # aws_iam_policy_document.json is used as assume_role_policy on IAM roles.
  # The AWS provider validates JSON at plan time, so the mock must return
  # a valid (empty) policy document.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  # aws_iam_session_context.issuer_arn is used by the upstream EKS module as
  # principal_arn for the cluster-creator access entry — must be a valid ARN.
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
variables {
  name                  = "acme"
  environment           = "mainnet"
  vpc_id                = "vpc-00000000000000000"
  private_subnet_ids    = ["subnet-aaaaaaaaaaaaaaaa1", "subnet-aaaaaaaaaaaaaaaa2"]
  additional_subnet_ids = ["subnet-bbbbbbbbbbbbbbbb1", "subnet-bbbbbbbbbbbbbbbb2"]
  cluster               = {}
  addons                = {}
  node_groups           = {}
  karpenter             = { enabled = false }
}

# =============================================================================
# Cluster name
#
# local.cluster_name = coalesce(var.cluster.name_override, "${var.name}-${var.environment}")
#
# output.cluster_name uses aws_eks_cluster.this.id (known after apply — cannot
# assert its value at plan time). We use aws_iam_policy.karpenter_encryption[0].name
# as a proxy: it is set to "${local.cluster_name}-ClusterEncryptionPolicy" and
# IS plan-time known because it is a directly configured argument.
# =============================================================================

run "cluster_name_defaults_to_name_dash_env" {
  command = plan

  variables {
    karpenter = {
      enabled              = true
      rule_name_prefix     = "test"
      controller_nodegroup = { enabled = false }
    }
  }

  assert {
    condition     = aws_iam_policy.karpenter_encryption[0].name == "acme-mainnet-ClusterEncryptionPolicy"
    error_message = "Cluster name must default to '<name>-<environment>'."
  }
}

run "name_override_changes_cluster_name" {
  command = plan

  variables {
    cluster = { name_override = "acme" }
    karpenter = {
      enabled              = true
      rule_name_prefix     = "test"
      controller_nodegroup = { enabled = false }
    }
  }

  assert {
    condition     = aws_iam_policy.karpenter_encryption[0].name == "acme-ClusterEncryptionPolicy"
    error_message = "name_override must replace the computed '<name>-<env>' cluster name."
  }
}

# =============================================================================
#  Karpenter disabled
# =============================================================================

# Absorbs null output assertions (previously a separate test).
run "karpenter_disabled_creates_no_resources" {
  command = plan

  assert {
    condition     = length(module.karpenter) == 0
    error_message = "Karpenter module must not be created when karpenter.enabled = false."
  }

  assert {
    condition     = length(aws_iam_policy.karpenter_encryption) == 0
    error_message = "karpenter_encryption IAM policy must not be created when disabled."
  }

  assert {
    condition     = length(aws_iam_policy.karpenter_instance_profile) == 0
    error_message = "karpenter_instance_profile IAM policy must not be created when disabled."
  }

  assert {
    condition     = length(aws_iam_service_linked_role.spot) == 0
    error_message = "Spot service-linked role must not be created when Karpenter is disabled."
  }

  assert {
    condition     = output.karpenter_iam_role_arn == null
    error_message = "karpenter_iam_role_arn must be null when karpenter.enabled = false."
  }

  assert {
    condition     = output.karpenter_node_iam_role_arn == null
    error_message = "karpenter_node_iam_role_arn must be null when karpenter.enabled = false."
  }

  assert {
    condition     = output.karpenter_queue_name == null
    error_message = "karpenter_queue_name must be null when karpenter.enabled = false."
  }
}

# =============================================================================
#  Karpenter enabled
# =============================================================================

run "karpenter_enabled_creates_all_resources" {
  command = plan

  variables {
    karpenter = {
      enabled              = true
      rule_name_prefix     = "coproc"
      controller_nodegroup = { enabled = false }
    }
  }

  assert {
    condition     = length(module.karpenter) == 1
    error_message = "Karpenter module must be created when karpenter.enabled = true."
  }

  assert {
    condition     = length(aws_iam_policy.karpenter_encryption) == 1
    error_message = "karpenter_encryption IAM policy must be created when enabled."
  }

  assert {
    condition     = length(aws_iam_policy.karpenter_instance_profile) == 1
    error_message = "karpenter_instance_profile IAM policy must be created when enabled."
  }

  assert {
    condition     = length(aws_iam_service_linked_role.spot) == 1
    error_message = "Spot service-linked role must be created when Karpenter is enabled."
  }
}

run "karpenter_encryption_policy_name_includes_cluster_name" {
  command = plan

  variables {
    karpenter = {
      enabled              = true
      rule_name_prefix     = "coproc"
      controller_nodegroup = { enabled = false }
    }
  }

  assert {
    condition     = aws_iam_policy.karpenter_encryption[0].name == "acme-mainnet-ClusterEncryptionPolicy"
    error_message = "karpenter_encryption policy name must include the cluster name."
  }

  assert {
    condition     = aws_iam_policy.karpenter_instance_profile[0].name == "acme-mainnet-KarpenterInstanceProfileManagement"
    error_message = "karpenter_instance_profile policy name must include the cluster name."
  }
}

# =============================================================================
#  Admin role access entries
# =============================================================================

run "no_access_entries_with_empty_admin_role_arns" {
  command = plan

  assert {
    condition     = length(aws_eks_access_entry.admin_roles) == 0
    error_message = "No EKS access entries must be created when admin_role_arns is empty."
  }

  assert {
    condition     = length(aws_eks_access_policy_association.admin_roles) == 0
    error_message = "No EKS access policy associations must be created when admin_role_arns is empty."
  }
}

run "one_access_entry_per_admin_role_arn" {
  command = plan

  variables {
    cluster = {
      admin_role_arns = [
        "arn:aws:iam::123456789012:role/AdminA",
        "arn:aws:iam::123456789012:role/AdminB",
      ]
    }
  }

  assert {
    condition     = length(aws_eks_access_entry.admin_roles) == 2
    error_message = "One EKS access entry must be created per admin role ARN."
  }

  assert {
    condition     = length(aws_eks_access_policy_association.admin_roles) == 2
    error_message = "One EKS access policy association must be created per admin role ARN."
  }
}

# =============================================================================
#  Variable validation
# =============================================================================

run "rejects_eks_version_below_1_28" {
  command = plan

  variables {
    cluster = { version = "1.27" }
  }

  expect_failures = [var.cluster]
}

run "rejects_karpenter_rule_name_prefix_over_20_chars" {
  command = plan

  variables {
    karpenter = {
      enabled          = true
      rule_name_prefix = "this-prefix-is-too-long" # 23 chars
    }
  }

  expect_failures = [var.karpenter]
}

# =============================================================================
#  use_additional_subnets node group routing
# =============================================================================

run "node_group_with_additional_subnets_plans_without_error" {
  command = plan

  variables {
    node_groups = {
      groups = {
        zws_pool = {
          use_additional_subnets = true
          instance_types         = ["t3.xlarge"]
        }
      }
    }
  }

  assert {
    condition     = length(module.eks) > 0
    error_message = "EKS cluster must plan successfully when a node group uses additional subnets."
  }
}
