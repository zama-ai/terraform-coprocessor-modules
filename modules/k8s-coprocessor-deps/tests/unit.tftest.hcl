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
        coprocessor = { enabled = false }
        db_admin    = { enabled = false }
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
        coprocessor = { enabled = false }
        db_admin    = { enabled = false }
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

run "defaults_coprocessor_sa_is_created" {
  command = plan

  variables {
    s3_bucket_arns = { coprocessor = "arn:aws:s3:::acme-testnet-coprocessor" }
    k8s = {
      enabled = true
      service_accounts = {
        coprocessor = { enabled = true }
        db_admin    = { enabled = false }
      }
      storage_classes = {
        gp3 = { enabled = false }
      }
      namespaces = { coproc = {} }
    }
  }

  assert {
    condition     = contains(keys(kubernetes_service_account.this), "coprocessor")
    error_message = "Built-in coprocessor service account must be created."
  }

  assert {
    condition     = kubernetes_service_account.this["coprocessor"].metadata[0].name == "coprocessor"
    error_message = "Built-in coprocessor service account name must be 'coprocessor'."
  }

  assert {
    condition     = kubernetes_service_account.this["coprocessor"].metadata[0].namespace == "coproc"
    error_message = "Built-in coprocessor service account must use default_namespace."
  }

  assert {
    condition     = contains(keys(aws_iam_role.service_account), "coprocessor")
    error_message = "Built-in coprocessor must create an IRSA role."
  }
}

run "defaults_db_admin_sa_is_created" {
  command = plan

  variables {
    rds_master_secret_arn = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:rds!db-test"
    k8s = {
      enabled = true
      service_accounts = {
        coprocessor = { enabled = false }
        db_admin    = { enabled = true }
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
        coprocessor = { enabled = false }
        db_admin    = { enabled = false }
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

run "defaults_coprocessor_s3_bucket_key_override_is_respected" {
  command = plan

  variables {
    s3_bucket_arns = { my-custom-bucket = "arn:aws:s3:::acme-testnet-custom" }
    k8s = {
      enabled = true
      service_accounts = {
        coprocessor = { enabled = true, s3_bucket_key = "my-custom-bucket" }
        db_admin    = { enabled = false }
      }
      storage_classes = {
        gp3 = { enabled = false }
      }
      namespaces = { coproc = {} }
    }
  }

  assert {
    condition     = contains(keys(kubernetes_service_account.this), "coprocessor")
    error_message = "Coprocessor service account must still be created with a custom s3_bucket_key."
  }
}

run "extra_service_account_overrides_builtin_with_same_key" {
  command = plan

  variables {
    k8s = {
      enabled = true
      service_accounts = {
        coprocessor = { enabled = true }
        db_admin    = { enabled = false }
        extra = {
          coprocessor = {
            name = "coprocessor"
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
    condition     = contains(keys(kubernetes_service_account.this), "coprocessor")
    error_message = "The coprocessor service account must still exist after the override."
  }
}
