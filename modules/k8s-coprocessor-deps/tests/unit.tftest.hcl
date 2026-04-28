mock_provider "aws" {
  # aws_iam_policy_document.json is used as assume_role_policy on IAM roles.
  # The AWS provider validates JSON at plan time, so the mock must return
  # a valid (empty) policy document.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}


# Shared defaults across all runs.
variables {
  partner_name      = "acme"
  environment       = "testnet"
  oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLE1234567890"
}

# =============================================================================
#  enabled = false
# =============================================================================

run "disabled_creates_no_resources" {
  command = plan

  variables {
    k8s = { enabled = false }
  }

  assert {
    condition     = length(kubernetes_namespace.this) == 0
    error_message = "No namespaces must be created when k8s.enabled = false."
  }

  assert {
    condition     = length(kubernetes_service_account.this) == 0
    error_message = "No service accounts must be created when k8s.enabled = false."
  }

  assert {
    condition     = length(aws_iam_policy.service_account) == 0
    error_message = "No IAM policies must be created when k8s.enabled = false."
  }

  assert {
    condition     = length(aws_iam_role.service_account) == 0
    error_message = "No IAM roles must be created when k8s.enabled = false."
  }

  assert {
    condition     = length(kubernetes_service.external_name) == 0
    error_message = "No ExternalName services must be created when k8s.enabled = false."
  }

  assert {
    condition     = length(kubernetes_storage_class_v1.this) == 0
    error_message = "No storage classes must be created when k8s.enabled = false."
  }

  assert {
    condition     = length(kubernetes_config_map.db_admin_secret_id) == 0
    error_message = "No db-admin configmap must be created when k8s.enabled = false."
  }

  assert {
    condition     = length(kubernetes_config_map.coprocessor_config) == 0
    error_message = "No coprocessor configmap must be created when k8s.enabled = false."
  }
}

# =============================================================================
#  Namespaces
# =============================================================================

run "one_namespace_resource_per_map_entry" {
  command = plan

  variables {
    k8s = {
      enabled = true
      namespaces = {
        coprocessor         = {}
        coprocessor-workers = {}
      }
    }
  }

  assert {
    condition     = length(kubernetes_namespace.this) == 2
    error_message = "One kubernetes_namespace must be created per namespaces map entry."
  }
}

run "namespace_name_matches_map_key" {
  command = plan

  variables {
    k8s = {
      enabled = true
      namespaces = {
        coprocessor = {}
      }
    }
  }

  assert {
    condition     = kubernetes_namespace.this["coprocessor"].metadata[0].name == "coprocessor"
    error_message = "Namespace name must match the map key."
  }
}

run "namespace_labels_and_annotations_are_merged" {
  command = plan

  variables {
    k8s = {
      enabled = true
      namespaces = {
        coprocessor = {
          labels      = { "team" = "platform" }
          annotations = { "owner" = "infra" }
        }
      }
    }
  }

  assert {
    condition     = kubernetes_namespace.this["coprocessor"].metadata[0].labels["team"] == "platform"
    error_message = "User-supplied namespace labels must be present."
  }

  assert {
    condition     = kubernetes_namespace.this["coprocessor"].metadata[0].annotations["owner"] == "infra"
    error_message = "User-supplied namespace annotations must be present."
  }
}

# =============================================================================
#  Service accounts + IAM
# =============================================================================

run "one_set_of_iam_resources_per_service_account" {
  command = plan

  variables {
    k8s = {
      enabled = true
      service_accounts = {
        sns_worker = { enabled = false }
        db_admin   = { enabled = false }
        tx_sender  = { enabled = false }
        extra = {
          custom-sns = {
            name = "custom-sns"
            iam_policy_statements = [
              {
                effect    = "Allow"
                actions   = ["sns:Publish"]
                resources = ["arn:aws:sns:eu-west-1:123456789012:my-topic"]
              }
            ]
          }
          coprocessor = {
            name = "coprocessor"
            iam_policy_statements = [
              {
                effect    = "Allow"
                actions   = ["s3:GetObject"]
                resources = ["arn:aws:s3:::my-bucket/*"]
              }
            ]
          }
        }
      }
      storage_classes = {
        gp3 = { enabled = false }
      }
    }
  }

  assert {
    condition     = length(kubernetes_service_account.this) == 2
    error_message = "One kubernetes_service_account must be created per service_accounts entry."
  }

  assert {
    condition     = length(aws_iam_policy.service_account) == 2
    error_message = "One IAM policy must be created per service_accounts entry."
  }

  assert {
    condition     = length(aws_iam_role.service_account) == 2
    error_message = "One IAM role must be created per service_accounts entry."
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.service_account) == 2
    error_message = "One IAM role policy attachment must be created per service_accounts entry."
  }
}

run "iam_role_name_defaults_to_key_partner_env" {
  command = plan

  variables {
    k8s = {
      enabled = true
      service_accounts = {
        extra = {
          sns-worker = {
            name = "sns-worker"
            iam_policy_statements = [
              {
                effect    = "Allow"
                actions   = ["sns:Publish"]
                resources = ["arn:aws:sns:eu-west-1:123456789012:my-topic"]
              }
            ]
          }
        }
      }
    }
  }

  assert {
    condition     = aws_iam_role.service_account["sns-worker"].name == "sns-worker-acme-testnet"
    error_message = "IAM role name must default to '<key>-<partner_name>-<environment>'."
  }

  assert {
    condition     = aws_iam_policy.service_account["sns-worker"].name == "sns-worker-acme-testnet"
    error_message = "IAM policy name must default to '<key>-<partner_name>-<environment>'."
  }
}

run "iam_role_name_override_is_respected" {
  command = plan

  variables {
    k8s = {
      enabled = true
      service_accounts = {
        extra = {
          sns-worker = {
            name                   = "sns-worker"
            iam_role_name_override = "my-custom-role-name"
            iam_policy_statements = [
              {
                effect    = "Allow"
                actions   = ["sns:Publish"]
                resources = ["arn:aws:sns:eu-west-1:123456789012:my-topic"]
              }
            ]
          }
        }
      }
    }
  }

  assert {
    condition     = aws_iam_role.service_account["sns-worker"].name == "my-custom-role-name"
    error_message = "iam_role_name_override must replace the computed role name."
  }
}

# =============================================================================
#  default_namespace fallback
# =============================================================================

run "sa_without_namespace_uses_default_namespace" {
  command = plan

  variables {
    k8s = {
      enabled           = true
      default_namespace = "coprocessor"
      service_accounts = {
        extra = {
          sns-worker = {
            name = "sns-worker"
            iam_policy_statements = [
              {
                effect    = "Allow"
                actions   = ["sns:Publish"]
                resources = ["arn:aws:sns:eu-west-1:123456789012:my-topic"]
              }
            ]
          }
        }
      }
    }
  }

  assert {
    condition     = kubernetes_service_account.this["sns-worker"].metadata[0].namespace == "coprocessor"
    error_message = "Service account without explicit namespace must use k8s.default_namespace."
  }
}

run "sa_with_namespace_override_uses_its_own_namespace" {
  command = plan

  variables {
    k8s = {
      enabled           = true
      default_namespace = "coprocessor"
      service_accounts = {
        extra = {
          sns-worker = {
            name      = "sns-worker"
            namespace = "coprocessor-workers"
            iam_policy_statements = [
              {
                effect    = "Allow"
                actions   = ["sns:Publish"]
                resources = ["arn:aws:sns:eu-west-1:123456789012:my-topic"]
              }
            ]
          }
        }
      }
    }
  }

  assert {
    condition     = kubernetes_service_account.this["sns-worker"].metadata[0].namespace == "coprocessor-workers"
    error_message = "Service account with explicit namespace must use its own namespace, not default_namespace."
  }
}

# =============================================================================
#  ExternalName services
# =============================================================================

run "one_external_name_service_per_map_entry" {
  command = plan

  variables {
    k8s = {
      enabled = true
      external_name_services = {
        coprocessor-db    = { endpoint = "mydb.abc123.eu-west-1.rds.amazonaws.com:5432" }
        coprocessor-redis = { endpoint = "mycluster.abc123.euw1.cache.amazonaws.com:6379" }
      }
    }
  }

  assert {
    condition     = length(kubernetes_service.external_name) == 2
    error_message = "One ExternalName service must be created per external_name_services entry."
  }
}

run "external_name_service_strips_port_from_endpoint" {
  command = plan

  variables {
    k8s = {
      enabled = true
      external_name_services = {
        coprocessor-db = { endpoint = "mydb.abc123.eu-west-1.rds.amazonaws.com:5432" }
      }
    }
  }

  assert {
    condition     = kubernetes_service.external_name["coprocessor-db"].spec[0].external_name == "mydb.abc123.eu-west-1.rds.amazonaws.com"
    error_message = "ExternalName service must strip the port from the endpoint."
  }
}

run "external_name_service_uses_default_namespace" {
  command = plan

  variables {
    k8s = {
      enabled           = true
      default_namespace = "coprocessor"
      external_name_services = {
        coprocessor-db = { endpoint = "mydb.abc123.eu-west-1.rds.amazonaws.com:5432" }
      }
    }
  }

  assert {
    condition     = kubernetes_service.external_name["coprocessor-db"].metadata[0].namespace == "coprocessor"
    error_message = "ExternalName service without explicit namespace must use k8s.default_namespace."
  }
}

run "external_name_service_namespace_override_is_respected" {
  command = plan

  variables {
    k8s = {
      enabled           = true
      default_namespace = "coprocessor"
      external_name_services = {
        coprocessor-db = {
          endpoint  = "mydb.abc123.eu-west-1.rds.amazonaws.com:5432"
          namespace = "data-plane"
        }
      }
    }
  }

  assert {
    condition     = kubernetes_service.external_name["coprocessor-db"].metadata[0].namespace == "data-plane"
    error_message = "ExternalName service with explicit namespace must use its own namespace, not default_namespace."
  }
}

# =============================================================================
#  Storage classes
# =============================================================================

run "one_storage_class_per_map_entry" {
  command = plan

  variables {
    k8s = {
      enabled = true
      storage_classes = {
        extra = {
          gp3  = { provisioner = "ebs.csi.aws.com" }
          gp3i = { provisioner = "ebs.csi.aws.com", parameters = { type = "gp3", iops = "16000" } }
        }
      }
    }
  }

  assert {
    condition     = length(kubernetes_storage_class_v1.this) == 2
    error_message = "One storage class must be created per storage_classes.extra map entry."
  }
}

run "storage_class_name_matches_map_key" {
  command = plan

  variables {
    k8s = {
      enabled = true
      storage_classes = {
        gp3 = { enabled = false }
        extra = {
          gp3 = { provisioner = "ebs.csi.aws.com" }
        }
      }
    }
  }

  assert {
    condition     = kubernetes_storage_class_v1.this["gp3"].metadata[0].name == "gp3"
    error_message = "Storage class name must match the map key."
  }
}

run "storage_class_provisioner_and_parameters_are_set" {
  command = plan

  variables {
    k8s = {
      enabled = true
      storage_classes = {
        gp3 = { enabled = false }
        extra = {
          gp3 = {
            provisioner = "ebs.csi.aws.com"
            parameters  = { type = "gp3", encrypted = "true", fsType = "ext4" }
          }
        }
      }
    }
  }

  assert {
    condition     = kubernetes_storage_class_v1.this["gp3"].storage_provisioner == "ebs.csi.aws.com"
    error_message = "Storage class provisioner must match the configured value."
  }

  assert {
    condition     = kubernetes_storage_class_v1.this["gp3"].parameters["type"] == "gp3"
    error_message = "Storage class parameters must be passed through."
  }
}

run "storage_class_default_annotation_is_applied" {
  command = plan

  variables {
    k8s = {
      enabled = true
      storage_classes = {
        gp3 = { enabled = false }
        extra = {
          gp3 = {
            provisioner = "ebs.csi.aws.com"
            annotations = { "storageclass.kubernetes.io/is-default-class" = "true" }
          }
        }
      }
    }
  }

  assert {
    condition     = kubernetes_storage_class_v1.this["gp3"].metadata[0].annotations["storageclass.kubernetes.io/is-default-class"] == "true"
    error_message = "Storage class default annotation must be applied."
  }
}

# =============================================================================
#  Built-in defaults
# =============================================================================

run "defaults_all_disabled_creates_no_builtin_resources" {
  command = plan

  variables {
    k8s = {
      enabled = true
      service_accounts = {
        sns_worker = { enabled = false }
        db_admin   = { enabled = false }
        tx_sender  = { enabled = false }
      }
      storage_classes = {
        gp3 = { enabled = false }
      }
    }
  }

  assert {
    condition     = length(kubernetes_service_account.this) == 0
    error_message = "No service accounts must be created when all defaults are disabled."
  }

  assert {
    condition     = length(kubernetes_storage_class_v1.this) == 0
    error_message = "No storage classes must be created when all defaults are disabled."
  }
}

run "defaults_sns_worker_sa_is_created" {
  command = plan

  variables {
    s3_bucket_arns = { coprocessor = "arn:aws:s3:::acme-testnet-coprocessor" }
    k8s = {
      enabled = true
      service_accounts = {
        sns_worker = { enabled = true }
        db_admin   = { enabled = false }
        tx_sender  = { enabled = false }
      }
      storage_classes = {
        gp3 = { enabled = false }
      }
      namespaces = { coproc = {} }
    }
  }

  assert {
    condition     = contains(keys(kubernetes_service_account.this), "sns-worker")
    error_message = "Built-in sns-worker service account must be created."
  }

  assert {
    condition     = kubernetes_service_account.this["sns-worker"].metadata[0].name == "sns-worker"
    error_message = "Built-in sns-worker service account name must be 'sns-worker'."
  }

  assert {
    condition     = kubernetes_service_account.this["sns-worker"].metadata[0].namespace == "coproc"
    error_message = "Built-in sns-worker service account must use default_namespace."
  }

  assert {
    condition     = contains(keys(aws_iam_role.service_account), "sns-worker")
    error_message = "Built-in sns-worker must create an IRSA role."
  }
}

run "defaults_db_admin_sa_is_created" {
  command = plan

  variables {
    rds_master_secret_arn = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:rds!db-test"
    k8s = {
      enabled = true
      service_accounts = {
        sns_worker = { enabled = false }
        db_admin   = { enabled = true }
        tx_sender  = { enabled = false }
      }
      storage_classes = {
        gp3 = { enabled = false }
      }
      namespaces = { coproc-admin = {} }
    }
  }

  assert {
    condition     = contains(keys(kubernetes_service_account.this), "db-admin")
    error_message = "Built-in db-admin service account must be created."
  }

  assert {
    condition     = kubernetes_service_account.this["db-admin"].metadata[0].namespace == "coproc-admin"
    error_message = "Built-in db-admin service account must use the coproc-admin namespace."
  }

  assert {
    condition     = contains(keys(aws_iam_role.service_account), "db-admin")
    error_message = "Built-in db-admin must create an IRSA role."
  }
}

run "defaults_gp3_storage_class_is_created" {
  command = plan

  variables {
    k8s = {
      enabled = true
      service_accounts = {
        sns_worker = { enabled = false }
        db_admin   = { enabled = false }
        tx_sender  = { enabled = false }
      }
      storage_classes = {
        gp3 = { enabled = true }
      }
    }
  }

  assert {
    condition     = contains(keys(kubernetes_storage_class_v1.this), "gp3")
    error_message = "Built-in gp3 storage class must be created."
  }

  assert {
    condition     = kubernetes_storage_class_v1.this["gp3"].storage_provisioner == "ebs.csi.aws.com"
    error_message = "Built-in gp3 storage class must use the EBS CSI provisioner."
  }

  assert {
    condition     = kubernetes_storage_class_v1.this["gp3"].parameters["encrypted"] == "true"
    error_message = "Built-in gp3 storage class must have encrypted = true."
  }

  assert {
    condition     = kubernetes_storage_class_v1.this["gp3"].metadata[0].annotations["storageclass.kubernetes.io/is-default-class"] == "true"
    error_message = "Built-in gp3 storage class must be marked as the cluster default."
  }
}

run "defaults_sns_worker_s3_bucket_key_override_is_respected" {
  command = plan

  variables {
    s3_bucket_arns = { my-custom-bucket = "arn:aws:s3:::acme-testnet-custom" }
    k8s = {
      enabled = true
      service_accounts = {
        sns_worker = { enabled = true, s3_bucket_key = "my-custom-bucket" }
        db_admin   = { enabled = false }
        tx_sender  = { enabled = false }
      }
      storage_classes = {
        gp3 = { enabled = false }
      }
      namespaces = { coproc = {} }
    }
  }

  assert {
    condition     = contains(keys(kubernetes_service_account.this), "sns-worker")
    error_message = "sns-worker service account must still be created with a custom s3_bucket_key."
  }
}

run "defaults_tx_sender_sa_is_created_with_kms_access" {
  command = plan

  variables {
    kms_key_arn = "arn:aws:kms:eu-west-1:123456789012:key/abcd1234-ef56-7890-abcd-ef1234567890"
    k8s = {
      enabled = true
      service_accounts = {
        sns_worker = { enabled = false }
        db_admin   = { enabled = false }
        tx_sender  = { enabled = true }
      }
      storage_classes = {
        gp3 = { enabled = false }
      }
      namespaces = { gw-blockchain = {} }
    }
  }

  assert {
    condition     = contains(keys(kubernetes_service_account.this), "tx-sender")
    error_message = "Built-in tx-sender service account must be created."
  }

  assert {
    condition     = kubernetes_service_account.this["tx-sender"].metadata[0].name == "tx-sender"
    error_message = "Built-in tx-sender service account name must be 'tx-sender'."
  }

  assert {
    condition     = kubernetes_service_account.this["tx-sender"].metadata[0].namespace == "gw-blockchain"
    error_message = "Built-in tx-sender service account must be in the gw-blockchain namespace."
  }

  assert {
    condition     = aws_iam_role.service_account["tx-sender"].name == "tx-sender-acme-testnet"
    error_message = "tx-sender IAM role must follow '<key>-<partner_name>-<environment>' pattern."
  }
}

run "db_admin_secret_id_configmap_is_created" {
  command = plan

  variables {
    rds_master_secret_arn = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:rds!db-test"
    k8s = {
      enabled    = true
      namespaces = { coproc-admin = {} }
      service_accounts = {
        sns_worker = { enabled = false }
        db_admin   = { enabled = true }
        tx_sender  = { enabled = false }
      }
      storage_classes = {
        gp3 = { enabled = false }
      }
    }
  }

  assert {
    condition     = length(kubernetes_config_map.db_admin_secret_id) == 1
    error_message = "db-admin configmap must be created when k8s.enabled = true."
  }

  assert {
    condition     = kubernetes_config_map.db_admin_secret_id[0].metadata[0].name == "rds-admin-secret-id"
    error_message = "Configmap name must be 'rds-admin-secret-id'."
  }

  assert {
    condition     = kubernetes_config_map.db_admin_secret_id[0].metadata[0].namespace == "coproc-admin"
    error_message = "Configmap must be created in the coproc-admin namespace."
  }

  assert {
    condition     = kubernetes_config_map.db_admin_secret_id[0].data["RDS_ADMIN_SECRET_ID"] == "arn:aws:secretsmanager:eu-west-1:123456789012:secret:rds!db-test"
    error_message = "Configmap data.RDS_ADMIN_SECRET_ID must equal the supplied rds_master_secret_arn."
  }
}

run "coprocessor_config_configmap_is_created_per_target_namespace" {
  command = plan

  variables {
    s3_bucket_names = { coprocessor = "acme-testnet-coprocessor-abc123" }
    k8s = {
      enabled = true
      namespaces = {
        coproc         = {}
        eth-blockchain = {}
        gw-blockchain  = {}
      }
      external_name_services = {
        coprocessor-database = { endpoint = "mydb.abc.eu-west-1.rds.amazonaws.com:5432" }
      }
      service_accounts = {
        sns_worker = { enabled = false }
        db_admin   = { enabled = false }
        tx_sender  = { enabled = false }
      }
      storage_classes = {
        gp3 = { enabled = false }
      }
    }
  }

  assert {
    condition     = length(kubernetes_config_map.coprocessor_config) == 3
    error_message = "One coprocessor-config configmap must be created per target namespace."
  }

  assert {
    condition     = kubernetes_config_map.coprocessor_config["coproc"].data["S3_BUCKET_NAME"] == "acme-testnet-coprocessor-abc123"
    error_message = "S3_BUCKET_NAME must equal the supplied bucket name for the configured s3_bucket_key."
  }

  assert {
    condition     = kubernetes_config_map.coprocessor_config["coproc"].data["DATABASE_ENDPOINT"] == "coprocessor-database.coproc.svc.cluster.local"
    error_message = "DATABASE_ENDPOINT must be the in-cluster DNS name of the coprocessor-database ExternalName service."
  }
}

run "extra_service_account_overrides_builtin_with_same_key" {
  command = plan

  variables {
    k8s = {
      enabled = true
      service_accounts = {
        sns_worker = { enabled = true }
        db_admin   = { enabled = false }
        tx_sender  = { enabled = false }
        extra = {
          sns-worker = {
            name = "sns-worker"
            iam_policy_statements = [
              {
                effect    = "Allow"
                actions   = ["s3:GetObject"]
                resources = ["arn:aws:s3:::override-bucket/*"]
              }
            ]
          }
        }
      }
      storage_classes = {
        gp3 = { enabled = false }
      }
    }
  }

  assert {
    condition     = length(kubernetes_service_account.this) == 1
    error_message = "Extra entry must override the built-in — no duplicate service account."
  }

  assert {
    condition     = contains(keys(kubernetes_service_account.this), "sns-worker")
    error_message = "The sns-worker service account must still exist after the override."
  }
}
