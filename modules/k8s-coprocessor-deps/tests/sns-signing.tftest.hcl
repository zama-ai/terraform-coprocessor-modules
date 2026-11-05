mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}
mock_provider "kubernetes" {}

variables {
  partner_name                 = "acme"
  environment                  = "testnet"
  oidc_provider_arn            = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLE"
  rds_client_security_group_id = "sg-0123456789abcdef0"
  kms_key_arn                  = "arn:aws:kms:eu-west-1:123456789012:key/11111111-2222-3333-4444-555555555555"
  s3_bucket_arns               = { coprocessor = "arn:aws:s3:::acme-ciphertexts" }
  k8s = {
    enabled = true
    service_accounts = {
      sns_worker = { enabled = true }
      tx_sender  = { enabled = false }
      db_admin   = { enabled = false }
    }
  }
}

run "sns_signing_defaults_on_and_preserves_bucket_writes" {
  command = plan
  assert {
    condition     = kubernetes_service_account.this["sns-worker"].metadata[0].namespace == "coproc"
    error_message = "SNS service account must remain in the workers namespace."
  }
  assert {
    condition = anytrue([for s in data.aws_iam_policy_document.service_account["sns-worker"].statement :
      contains(s.actions, "kms:Sign") && contains(s.actions, "kms:GetPublicKey") && s.resources == toset([var.kms_key_arn])
    ])
    error_message = "Signing must be allowed only on the configured key."
  }
  assert {
    condition = anytrue([for s in data.aws_iam_policy_document.service_account["sns-worker"].statement :
      contains(s.actions, "s3:*Object") && contains(s.actions, "s3:ListBucket") && s.resources == toset(["arn:aws:s3:::acme-ciphertexts", "arn:aws:s3:::acme-ciphertexts/*"])
    ])
    error_message = "SNS must retain ciphertext bucket reads, PutObject writes and listing."
  }
  assert {
    condition     = kubernetes_config_map.coprocessor_sns_worker[0].metadata[0].name == "coprocessor-sns-worker" && kubernetes_config_map.coprocessor_sns_worker[0].metadata[0].namespace == "coproc" && kubernetes_config_map.coprocessor_sns_worker[0].data["AWS_KEY_ID"] == var.kms_key_arn
    error_message = "Signing ConfigMap must match the Helm name, key and namespace."
  }
}

run "explicit_opt_out_has_no_signing_access_or_configmap" {
  command = plan
  variables {
    k8s = {
      enabled = true
      service_accounts = {
        sns_worker = { enabled = true, kms_key_access = false }
        tx_sender  = { enabled = false }
        db_admin   = { enabled = false }
      }
    }
  }
  assert {
    condition     = length(kubernetes_config_map.coprocessor_sns_worker) == 0 && alltrue([for s in data.aws_iam_policy_document.service_account["sns-worker"].statement : !contains(s.actions, "kms:Sign")])
    error_message = "An explicit opt-out must omit signing permissions and configuration."
  }
}

run "disabled_sns_has_no_signing_configmap" {
  command = plan
  variables {
    k8s = { enabled = true, service_accounts = { sns_worker = { enabled = false, kms_key_access = true }, tx_sender = { enabled = false }, db_admin = { enabled = false } } }
  }
  assert {
    condition     = length(kubernetes_config_map.coprocessor_sns_worker) == 0
    error_message = "Disabled SNS must not create signing configuration."
  }
}

run "custom_namespace_is_used_for_signing_configmap" {
  command = plan
  variables {
    k8s = { enabled = true, default_namespace = "custom-workers", service_accounts = { sns_worker = { kms_key_access = true }, tx_sender = { enabled = false }, db_admin = { enabled = false } } }
  }
  assert {
    condition     = kubernetes_config_map.coprocessor_sns_worker[0].metadata[0].namespace == "custom-workers"
    error_message = "Signing configuration must follow the configured workers namespace."
  }
}

run "colocated_signers_have_distinct_configmaps" {
  command = plan
  variables {
    k8s = { enabled = true, default_namespace = "gw-blockchain", service_accounts = { sns_worker = { kms_key_access = true }, db_admin = { enabled = false } } }
  }
  assert {
    condition     = length(kubernetes_config_map.coprocessor_sns_worker) == 1 && length(kubernetes_config_map.coprocessor_tx_sender) == 1 && kubernetes_config_map.coprocessor_sns_worker[0].metadata[0].name != kubernetes_config_map.coprocessor_tx_sender[0].metadata[0].name
    error_message = "Colocated signers must each have their own distinctly named ConfigMap."
  }
}

run "sns_worker_role_name_override_is_rejected" {
  command = plan
  variables {
    k8s = {
      service_accounts = {
        extra = { sns-worker = { name = "sns-worker", iam_role_name_override = "custom-signer" } }
      }
    }
  }
  expect_failures = [var.k8s]
}

run "tx_sender_role_name_override_is_rejected" {
  command = plan
  variables {
    k8s = {
      service_accounts = {
        extra = { tx-sender = { name = "tx-sender", iam_role_name_override = "custom-signer" } }
      }
    }
  }
  expect_failures = [var.k8s]
}
