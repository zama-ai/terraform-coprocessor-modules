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
  k8s = {
    enabled          = true
    service_accounts = { sns_worker = { enabled = false }, tx_sender = { enabled = false }, db_admin = { enabled = false } }
  }
}
run "testnet_defaults_are_rendered_without_overrides" {
  command = plan
  assert {
    condition     = kubernetes_config_map.coprocessor_config["eth-blockchain"].data["ETH_FHEVM_BRANCH_ACTIVATION_BLOCK"] == "12126200" && kubernetes_config_map.coprocessor_config["polygon-blockchain"].data["POLYGON_FHEVM_BRANCH_ACTIVATION_BLOCK"] == "52745000"
    error_message = "Testnet heights must render as strings under the exact Helm reference keys."
  }
  assert {
    condition     = alltrue([for config in kubernetes_config_map.coprocessor_config : config.data["ETH_FHEVM_BRANCH_ACTIVATION_BLOCK"] == "12126200" && config.data["POLYGON_FHEVM_BRANCH_ACTIVATION_BLOCK"] == "52745000"])
    error_message = "Both activation heights must appear in every coprocessor-config ConfigMap."
  }
}
run "unknown_environment_omits_unconfigured_heights" {
  command = plan
  variables {
    environment = "devnet"
    k8s         = { enabled = true, service_accounts = { sns_worker = { enabled = false }, tx_sender = { enabled = false }, db_admin = { enabled = false } } }
  }
  assert {
    condition     = !contains(keys(kubernetes_config_map.coprocessor_config["eth-blockchain"].data), "ETH_FHEVM_BRANCH_ACTIVATION_BLOCK") && !contains(keys(kubernetes_config_map.coprocessor_config["polygon-blockchain"].data), "POLYGON_FHEVM_BRANCH_ACTIVATION_BLOCK")
    error_message = "Unconfigured deployments must not gain activation settings."
  }
}
run "explicit_heights_override_defaults_independently" {
  command = plan
  variables {
    k8s = { enabled = true, service_accounts = { sns_worker = { enabled = false }, tx_sender = { enabled = false }, db_admin = { enabled = false } }, branch_activation_blocks = { ethereum = 12345678, polygon = 56789012 } }
  }
  assert {
    condition     = alltrue([for config in kubernetes_config_map.coprocessor_config : config.data["ETH_FHEVM_BRANCH_ACTIVATION_BLOCK"] == "12345678" && config.data["POLYGON_FHEVM_BRANCH_ACTIVATION_BLOCK"] == "56789012"])
    error_message = "Each chain override must be replicated to every ConfigMap."
  }
}
run "invalid_heights_are_rejected" {
  command = plan
  variables {
    k8s = { branch_activation_blocks = { ethereum = -1, polygon = 1.5 } }
  }
  expect_failures = [var.k8s]
}

run "mainnet_defaults_are_rendered_without_overrides" {
  command = plan
  variables {
    environment = "mainnet"
  }
  assert {
    condition     = kubernetes_config_map.coprocessor_config["eth-blockchain"].data["ETH_FHEVM_BRANCH_ACTIVATION_BLOCK"] == "999999999" && kubernetes_config_map.coprocessor_config["polygon-blockchain"].data["POLYGON_FHEVM_BRANCH_ACTIVATION_BLOCK"] == "999999999"
    error_message = "Mainnet must receive the network's mock heights without tfvars overrides."
  }
}
run "partial_override_preserves_zero_and_defaults_other_chain" {
  command = plan
  variables {
    k8s = { enabled = true, service_accounts = { sns_worker = { enabled = false }, tx_sender = { enabled = false }, db_admin = { enabled = false } }, branch_activation_blocks = { ethereum = 0 } }
  }
  assert {
    condition     = kubernetes_config_map.coprocessor_config["eth-blockchain"].data["ETH_FHEVM_BRANCH_ACTIVATION_BLOCK"] == "0" && kubernetes_config_map.coprocessor_config["polygon-blockchain"].data["POLYGON_FHEVM_BRANCH_ACTIVATION_BLOCK"] == "52745000"
    error_message = "An explicit zero must override Ethereum without suppressing Polygon's default."
  }
}
run "null_chain_overrides_use_network_defaults" {
  command = plan
  variables {
    k8s = { enabled = true, service_accounts = { sns_worker = { enabled = false }, tx_sender = { enabled = false }, db_admin = { enabled = false } }, branch_activation_blocks = { ethereum = null, polygon = null } }
  }
  assert {
    condition     = kubernetes_config_map.coprocessor_config["eth-blockchain"].data["ETH_FHEVM_BRANCH_ACTIVATION_BLOCK"] == "12126200" && kubernetes_config_map.coprocessor_config["polygon-blockchain"].data["POLYGON_FHEVM_BRANCH_ACTIVATION_BLOCK"] == "52745000"
    error_message = "Null chain values must use environment defaults."
  }
}
