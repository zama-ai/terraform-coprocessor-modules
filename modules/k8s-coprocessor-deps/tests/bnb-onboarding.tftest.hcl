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
    enabled                = true
    namespaces             = { bnb-blockchain = {} }
    external_name_services = { coprocessor-database = { endpoint = "db.example.invalid:5432" } }
    service_accounts       = { sns_worker = { enabled = false }, tx_sender = { enabled = false }, db_admin = { enabled = false } }
  }
}

run "bnb_receives_namespace_database_config_and_rds_policy" {
  command = plan
  assert {
    condition     = toset([for policy in local.rds_client_policies : policy.namespace]) == toset(["coproc", "eth-blockchain", "gw-blockchain", "polygon-blockchain", "bnb-blockchain", "coproc-admin", "monitoring"])
    error_message = "Default RDS policies must cover the fixed coprocessor namespaces plus administration and monitoring."
  }
  assert {
    condition     = kubernetes_namespace.this["bnb-blockchain"].metadata[0].name == "bnb-blockchain"
    error_message = "The BNB namespace must be created."
  }
  assert {
    condition     = kubernetes_config_map.coprocessor_config["bnb-blockchain"].data["DATABASE_ENDPOINT"] == "coprocessor-database.coproc.svc.cluster.local"
    error_message = "BNB must resolve the shared coprocessor DB endpoint."
  }
  assert {
    condition     = kubernetes_manifest.security_group_policy["rds-client-bnb-blockchain"].manifest.spec.securityGroups.groupIds[0] == var.rds_client_security_group_id && kubernetes_manifest.security_group_policy["rds-client-bnb-blockchain"].manifest.spec.podSelector.matchLabels["network/rds-client"] == "true"
    error_message = "BNB must receive the default RDS group and pod selector."
  }
}

run "disabled_namespace_creation_retains_fixed_config_and_policy_destinations" {
  command = plan
  variables {
    k8s = {
      enabled          = true
      namespaces       = { bnb-blockchain = { enabled = false } }
      service_accounts = { sns_worker = { enabled = false }, tx_sender = { enabled = false }, db_admin = { enabled = false } }
    }
  }
  assert {
    condition     = contains(keys(kubernetes_config_map.coprocessor_config), "bnb-blockchain") && contains(keys(kubernetes_manifest.security_group_policy), "rds-client-bnb-blockchain") && length(kubernetes_namespace.this) == 0
    error_message = "Disabling namespace creation must not alter the fixed ConfigMap and RDS policy destinations."
  }
}

run "explicit_policy_namespace_override_is_respected" {
  command = plan
  variables {
    k8s = {
      enabled                 = true
      namespaces              = { bnb-blockchain = {} }
      service_accounts        = { sns_worker = { enabled = false }, tx_sender = { enabled = false }, db_admin = { enabled = false } }
      security_group_policies = { rds_client = { namespaces = ["coproc"] } }
    }
  }
  assert {
    condition     = length(kubernetes_manifest.security_group_policy) == 1 && !contains(keys(kubernetes_manifest.security_group_policy), "rds-client-bnb-blockchain")
    error_message = "An explicit RDS namespace list must replace default destinations."
  }
}

run "additional_chain_does_not_expand_fixed_namespace_lists" {
  command = plan
  variables {
    k8s = {
      enabled          = true
      namespaces       = { hoodi-blockchain = {} }
      service_accounts = { sns_worker = { enabled = false }, tx_sender = { enabled = false }, db_admin = { enabled = false } }
    }
  }
  assert {
    condition     = !contains(keys(kubernetes_config_map.coprocessor_config), "hoodi-blockchain") && !contains(keys(kubernetes_manifest.security_group_policy), "rds-client-hoodi-blockchain") && contains(keys(kubernetes_config_map.coprocessor_config), "bnb-blockchain")
    error_message = "Additional chain namespaces must not automatically expand the ConfigMap or RDS policy destinations."
  }
}
