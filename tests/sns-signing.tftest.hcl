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

mock_provider "kubernetes" {}

variables {
  partner_name = "acme"
  environment  = "mainnet"
  aws_region   = "eu-west-1"
  networking = {
    enabled      = false
    vpc          = { cidr = "10.0.0.0/16", availability_zones = ["eu-west-1a", "eu-west-1b"] }
    existing_vpc = { vpc_id = "vpc-00000000000000000", private_subnet_ids = ["subnet-aaaaaaaaaaaaaaaa1"] }
  }
  eks = { enabled = false }
  s3  = { buckets = { coprocessor = {} } }
}

run "sns_signing_role_is_added_to_key_consumers_by_default" {
  command = plan
  variables {
    kms                 = { enabled = true }
    kubernetes_provider = { oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLE" }
    k8s_coprocessor_deps = {
      enabled                 = true
      service_accounts        = { tx_sender = { enabled = false }, db_admin = { enabled = false } }
      security_group_policies = { rds_client = { enabled = false } }
    }
  }
  assert {
    condition     = contains(local.kms_consumer_role_arns, "arn:aws:iam::123456789012:role/sns-worker-acme-mainnet") && length(time_sleep.wait_for_sns_worker_iam_propagation) == 1
    error_message = "SNS signing role must be authorized by the key and awaited before key creation."
  }
}

run "sns_worker_role_name_override_is_rejected" {
  command = plan
  variables {
    k8s_coprocessor_deps = {
      service_accounts = {
        extra = { sns-worker = { name = "sns-worker", iam_role_name_override = "custom-signer" } }
      }
    }
  }
  expect_failures = [var.k8s_coprocessor_deps]
}

run "tx_sender_role_name_override_is_rejected" {
  command = plan
  variables {
    k8s_coprocessor_deps = {
      service_accounts = {
        extra = { tx-sender = { name = "tx-sender", iam_role_name_override = "custom-signer" } }
      }
    }
  }
  expect_failures = [var.k8s_coprocessor_deps]
}

run "disabled_dependencies_skip_both_iam_waits" {
  command = plan
  variables {
    kms                  = { enabled = true }
    k8s_coprocessor_deps = { enabled = false }
  }
  assert {
    condition     = length(time_sleep.wait_for_tx_sender_iam_propagation) == 0 && length(time_sleep.wait_for_sns_worker_iam_propagation) == 0
    error_message = "KMS alone must not create waits for disabled Kubernetes dependencies."
  }
}

run "disabled_sns_skips_its_wait_and_key_authorization" {
  command = plan
  variables {
    kms                 = { enabled = true }
    kubernetes_provider = { oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLE" }
    k8s_coprocessor_deps = {
      enabled          = true
      service_accounts = { sns_worker = { enabled = false }, db_admin = { enabled = false } }
    }
  }
  assert {
    condition     = length(time_sleep.wait_for_tx_sender_iam_propagation) == 1 && length(time_sleep.wait_for_sns_worker_iam_propagation) == 0 && !contains(local.kms_consumer_role_arns, "arn:aws:iam::123456789012:role/sns-worker-acme-mainnet")
    error_message = "Disabled SNS must skip its wait and key authorization while tx-sender remains enabled."
  }
}
