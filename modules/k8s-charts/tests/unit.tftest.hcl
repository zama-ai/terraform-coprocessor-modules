mock_provider "helm" {}

mock_provider "kubernetes" {}

mock_provider "aws" {
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
#  No applications
# =============================================================================

run "empty_applications_creates_no_resources" {
  command = plan

  variables {
    applications = {}
  }

  assert {
    condition     = length(helm_release.this) == 0
    error_message = "No helm releases must be created when applications is empty."
  }

  assert {
    condition     = length(kubernetes_namespace.this) == 0
    error_message = "No namespaces must be created when applications is empty."
  }

  assert {
    condition     = length(aws_iam_role.irsa) == 0
    error_message = "No IRSA roles must be created when applications is empty."
  }
}

# =============================================================================
#  Namespace
# =============================================================================

run "namespace_create_true_creates_resource" {
  command = plan

  variables {
    applications = {
      karpenter = {
        namespace  = { name = "karpenter", create = true }
        helm_chart = { repository = "oci://public.ecr.aws/karpenter", chart = "karpenter", version = "1.8.2" }
      }
    }
  }

  assert {
    condition     = length(kubernetes_namespace.this) == 1
    error_message = "One namespace must be created when namespace.create = true."
  }

  assert {
    condition     = kubernetes_namespace.this["karpenter"].metadata[0].name == "karpenter"
    error_message = "Namespace name must match namespace.name."
  }
}

run "namespace_create_false_skips_resource" {
  command = plan

  variables {
    applications = {
      metrics-server = {
        namespace  = { name = "kube-system", create = false }
        helm_chart = { repository = "https://kubernetes-sigs.github.io/metrics-server", chart = "metrics-server", version = "3.13.0" }
      }
    }
  }

  assert {
    condition     = length(kubernetes_namespace.this) == 0
    error_message = "No namespace must be created when namespace.create = false."
  }
}

# =============================================================================
#  Helm release
# =============================================================================

run "one_release_per_helm_app" {
  command = plan

  variables {
    applications = {
      metrics-server = {
        namespace  = { name = "kube-system" }
        helm_chart = { repository = "https://kubernetes-sigs.github.io/metrics-server", chart = "metrics-server", version = "3.13.0" }
      }
      karpenter = {
        namespace  = { name = "karpenter", create = true }
        helm_chart = { repository = "oci://public.ecr.aws/karpenter", chart = "karpenter", version = "1.8.2" }
      }
    }
  }

  assert {
    condition     = length(helm_release.this) == 2
    error_message = "One helm release must be created per application with helm_chart set."
  }
}

run "helm_release_name_matches_map_key" {
  command = plan

  variables {
    applications = {
      metrics-server = {
        namespace  = { name = "kube-system" }
        helm_chart = { repository = "https://kubernetes-sigs.github.io/metrics-server", chart = "metrics-server", version = "3.13.0" }
      }
    }
  }

  assert {
    condition     = helm_release.this["metrics-server"].name == "metrics-server"
    error_message = "Helm release name must match the map key."
  }
}

run "helm_release_namespace_matches_namespace_name" {
  command = plan

  variables {
    applications = {
      metrics-server = {
        namespace  = { name = "kube-system" }
        helm_chart = { repository = "https://kubernetes-sigs.github.io/metrics-server", chart = "metrics-server", version = "3.13.0" }
      }
    }
  }

  assert {
    condition     = helm_release.this["metrics-server"].namespace == "kube-system"
    error_message = "Helm release namespace must match namespace.name."
  }
}

run "helm_release_skipped_when_helm_chart_null" {
  command = plan

  variables {
    applications = {
      no-helm-app = {
        namespace = { name = "default" }
      }
    }
  }

  assert {
    condition     = length(helm_release.this) == 0
    error_message = "No helm release must be created when helm_chart is null."
  }
}

# =============================================================================
#  Service account
# =============================================================================

run "service_account_create_true_creates_resource" {
  command = plan

  variables {
    applications = {
      external-secrets = {
        namespace = { name = "external-secrets", create = true }
        service_account = {
          create = true
          name   = "external-secrets"
        }
        helm_chart = { repository = "https://charts.external-secrets.io", chart = "external-secrets", version = "0.14.0" }
      }
    }
  }

  assert {
    condition     = length(kubernetes_service_account.this) == 1
    error_message = "One service account must be created when service_account.create = true."
  }

  assert {
    condition     = kubernetes_service_account.this["external-secrets"].metadata[0].name == "external-secrets"
    error_message = "Service account name must match service_account.name."
  }
}

run "service_account_create_false_skips_resource" {
  command = plan

  variables {
    applications = {
      karpenter = {
        namespace = { name = "karpenter", create = true }
        service_account = {
          create = false
          name   = "karpenter"
        }
        helm_chart = { repository = "oci://public.ecr.aws/karpenter", chart = "karpenter", version = "1.8.2" }
      }
    }
  }

  assert {
    condition     = length(kubernetes_service_account.this) == 0
    error_message = "No service account must be created when service_account.create = false."
  }
}

# =============================================================================
#  IRSA
# =============================================================================

run "irsa_disabled_creates_no_iam_resources" {
  command = plan

  variables {
    applications = {
      metrics-server = {
        namespace  = { name = "kube-system" }
        irsa       = { enabled = false }
        helm_chart = { repository = "https://kubernetes-sigs.github.io/metrics-server", chart = "metrics-server", version = "3.13.0" }
      }
    }
  }

  assert {
    condition     = length(aws_iam_role.irsa) == 0
    error_message = "No IRSA role must be created when irsa.enabled = false."
  }
}

run "irsa_enabled_creates_role_policy_and_attachment" {
  command = plan

  variables {
    applications = {
      external-secrets = {
        namespace = { name = "external-secrets", create = true }
        service_account = {
          create = true
          name   = "external-secrets"
        }
        irsa = {
          enabled = true
          policy_statements = [
            {
              actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
              resources = ["*"]
            }
          ]
        }
        helm_chart = { repository = "https://charts.external-secrets.io", chart = "external-secrets", version = "0.14.0" }
      }
    }
  }

  assert {
    condition     = length(aws_iam_role.irsa) == 1
    error_message = "One IRSA role must be created when irsa.enabled = true."
  }

  assert {
    condition     = length(aws_iam_policy.irsa) == 1
    error_message = "One IRSA policy must be created when irsa.enabled = true."
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.irsa) == 1
    error_message = "One IRSA role policy attachment must be created when irsa.enabled = true."
  }

  assert {
    condition     = aws_iam_role.irsa["external-secrets"].name == "external-secrets-acme-testnet"
    error_message = "IRSA role name must default to '<app_key>-<partner_name>-<environment>'."
  }
}

run "irsa_role_name_override_is_respected" {
  command = plan

  variables {
    applications = {
      external-secrets = {
        namespace = { name = "external-secrets" }
        service_account = {
          create = true
          name   = "external-secrets"
        }
        irsa = {
          enabled   = true
          role_name = "my-custom-eso-role"
          policy_statements = [
            {
              actions   = ["secretsmanager:GetSecretValue"]
              resources = ["*"]
            }
          ]
        }
        helm_chart = { repository = "https://charts.external-secrets.io", chart = "external-secrets", version = "0.14.0" }
      }
    }
  }

  assert {
    condition     = aws_iam_role.irsa["external-secrets"].name == "my-custom-eso-role"
    error_message = "irsa.role_name override must replace the computed role name."
  }
}
