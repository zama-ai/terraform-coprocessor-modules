mock_provider "helm" {}


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
    condition     = length(helm_release.apps) == 0
    error_message = "No helm releases must be created when applications is empty."
  }

  assert {
    condition     = length(helm_release.crds) == 0
    error_message = "No CRD releases must be created when applications is empty."
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
    condition     = length(helm_release.apps) == 2
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
    condition     = helm_release.apps["metrics-server"].name == "metrics-server"
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
    condition     = helm_release.apps["metrics-server"].namespace == "kube-system"
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
    condition     = length(helm_release.apps) == 0
    error_message = "No helm release must be created when helm_chart is null."
  }
}

run "helm_release_skipped_when_helm_chart_disabled" {
  command = plan

  variables {
    applications = {
      metrics-server = {
        namespace  = { name = "kube-system" }
        helm_chart = { repository = "https://kubernetes-sigs.github.io/metrics-server", chart = "metrics-server", version = "3.13.0", enabled = false }
      }
    }
  }

  assert {
    condition     = length(helm_release.apps) == 0
    error_message = "No helm release must be created when helm_chart.enabled = false."
  }

  assert {
    condition     = length(helm_release.crds) == 0
    error_message = "No CRD release must be created when helm_chart.enabled = false."
  }
}

# =============================================================================
#  CRD chart ordering
# =============================================================================

run "crd_chart_lands_in_crds_resource_not_apps" {
  command = plan

  variables {
    applications = {
      prometheus-operator-crds = {
        namespace  = { name = "monitoring" }
        helm_chart = { repository = "https://prometheus-community.github.io/helm-charts", chart = "prometheus-operator-crds", version = "28.0.1", crd_chart = true, atomic = false }
      }
      prometheus-postgres-exporter = {
        namespace  = { name = "monitoring" }
        helm_chart = { repository = "https://prometheus-community.github.io/helm-charts", chart = "prometheus-postgres-exporter", version = "7.3.0" }
      }
    }
  }

  assert {
    condition     = length(helm_release.crds) == 1
    error_message = "CRD chart must land in helm_release.crds."
  }

  assert {
    condition     = length(helm_release.apps) == 1
    error_message = "Non-CRD chart must land in helm_release.apps."
  }

  assert {
    condition     = contains(keys(helm_release.crds), "prometheus-operator-crds")
    error_message = "prometheus-operator-crds must be in helm_release.crds."
  }

  assert {
    condition     = contains(keys(helm_release.apps), "prometheus-postgres-exporter")
    error_message = "prometheus-postgres-exporter must be in helm_release.apps."
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
        helm_chart = { repository = "https://charts.external-secrets.io", chart = "external-secrets", version = "2.2.0" }
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
              effect    = "Allow"
              actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
              resources = ["*"]
            }
          ]
        }
        helm_chart = { repository = "https://charts.external-secrets.io", chart = "external-secrets", version = "2.2.0" }
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
              effect    = "Allow"
              actions   = ["secretsmanager:GetSecretValue"]
              resources = ["*"]
            }
          ]
        }
        helm_chart = { repository = "https://charts.external-secrets.io", chart = "external-secrets", version = "2.2.0" }
      }
    }
  }

  assert {
    condition     = aws_iam_role.irsa["external-secrets"].name == "my-custom-eso-role"
    error_message = "irsa.role_name override must replace the computed role name."
  }
}
