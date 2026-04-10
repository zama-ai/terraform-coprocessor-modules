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

# =============================================================================
#  set_computed merging
# =============================================================================

run "set_computed_values_are_merged_into_helm_release" {
  command = plan

  variables {
    applications = {
      karpenter = {
        namespace  = { name = "karpenter", create = true }
        helm_chart = { repository = "oci://public.ecr.aws/karpenter", chart = "karpenter", version = "1.8.2", set = { "replicas" = "1" } }
      }
    }
    set_computed = {
      karpenter = {
        "settings.clusterName"       = "acme-testnet"
        "settings.interruptionQueue" = "acme-testnet-karpenter"
      }
    }
  }

  assert {
    condition = contains(
      [for s in helm_release.apps["karpenter"].set : s.name],
      "settings.clusterName"
    )
    error_message = "set_computed keys must be present in the helm release set block."
  }

  assert {
    condition = contains(
      [for s in helm_release.apps["karpenter"].set : s.name],
      "replicas"
    )
    error_message = "helm_chart.set keys must be preserved when set_computed is merged."
  }
}

# =============================================================================
#  additional_manifests
# =============================================================================

run "additional_manifests_disabled_creates_no_manifest_resources" {
  command = plan

  variables {
    applications = {
      karpenter-nodepools = {
        namespace = { name = "karpenter" }
        additional_manifests = {
          enabled = false
          manifests = {
            nodepool = <<-YAML
              apiVersion: karpenter.sh/v1
              kind: NodePool
              metadata:
                name: default
              spec:
                template:
                  spec:
                    nodeClassRef:
                      group: karpenter.k8s.aws
                      kind: EC2NodeClass
                      name: default
                    requirements: []
                limits:
                  cpu: "10"
                disruption:
                  consolidationPolicy: WhenEmpty
                  consolidateAfter: 30s
            YAML
          }
        }
      }
    }
  }

  assert {
    condition     = length(kubernetes_manifest.additional) == 0
    error_message = "No manifests must be created when additional_manifests.enabled = false."
  }
}

run "additional_manifests_enabled_creates_manifest_resources" {
  command = plan

  variables {
    manifests_vars = {
      cluster_name = "acme-testnet"
      node_role    = "acme-testnet-Karpenter"
    }
    applications = {
      karpenter-nodepools = {
        namespace = { name = "karpenter" }
        additional_manifests = {
          enabled = true
          manifests = {
            nodepool = <<-YAML
              apiVersion: karpenter.sh/v1
              kind: NodePool
              metadata:
                name: default
              spec:
                template:
                  spec:
                    nodeClassRef:
                      group: karpenter.k8s.aws
                      kind: EC2NodeClass
                      name: default
                    requirements: []
                limits:
                  cpu: "10"
                disruption:
                  consolidationPolicy: WhenEmpty
                  consolidateAfter: 30s
            YAML
          }
        }
      }
    }
  }

  assert {
    condition     = length(kubernetes_manifest.additional) == 1
    error_message = "One manifest resource must be created per entry when additional_manifests.enabled = true."
  }

  assert {
    condition     = contains(keys(kubernetes_manifest.additional), "karpenter-nodepools/nodepool")
    error_message = "Manifest key must be '<app_key>/<manifest_key>'."
  }
}

run "manifests_vars_placeholders_are_substituted" {
  command = plan

  variables {
    manifests_vars = {
      cluster_name = "acme-testnet"
      node_role    = "acme-testnet-Karpenter"
    }
    applications = {
      karpenter-nodepools = {
        namespace = { name = "karpenter" }
        additional_manifests = {
          enabled = true
          manifests = {
            ec2nodeclass = <<-YAML
              apiVersion: karpenter.k8s.aws/v1
              kind: EC2NodeClass
              metadata:
                name: default
              spec:
                amiSelectorTerms:
                  - alias: al2023@latest
                role: __node_role__
                subnetSelectorTerms:
                  - tags:
                      karpenter.sh/discovery: __cluster_name__
                securityGroupSelectorTerms:
                  - tags:
                      karpenter.sh/discovery: __cluster_name__
            YAML
          }
        }
      }
    }
  }

  assert {
    condition     = kubernetes_manifest.additional["karpenter-nodepools/ec2nodeclass"].manifest.spec.role == "acme-testnet-Karpenter"
    error_message = "__node_role__ placeholder must be substituted with manifests_vars.node_role."
  }

  assert {
    condition     = kubernetes_manifest.additional["karpenter-nodepools/ec2nodeclass"].manifest.spec.subnetSelectorTerms[0].tags["karpenter.sh/discovery"] == "acme-testnet"
    error_message = "__cluster_name__ placeholder must be substituted with manifests_vars.cluster_name."
  }
}

# =============================================================================
#  Helm values placeholder substitution
# =============================================================================

run "helm_values_partner_and_network_placeholders_are_substituted" {
  command = plan

  variables {
    applications = {
      k8s-monitoring = {
        namespace = { name = "monitoring" }
        helm_chart = {
          repository = "https://grafana.github.io/helm-charts"
          chart      = "k8s-monitoring"
          version    = "3.8.1"
          values     = <<-YAML
            destinations:
              - name: grafana-cloud-metrics
                externalLabels:
                  partner: __partner__
                  network: __network__
          YAML
        }
      }
    }
  }

  assert {
    condition     = strcontains(helm_release.apps["k8s-monitoring"].values[0], "partner: acme")
    error_message = "__partner__ placeholder must be substituted with var.partner_name in helm values."
  }

  assert {
    condition     = strcontains(helm_release.apps["k8s-monitoring"].values[0], "network: testnet")
    error_message = "__network__ placeholder must be substituted with var.environment in helm values."
  }

  assert {
    condition     = !strcontains(helm_release.apps["k8s-monitoring"].values[0], "__partner__")
    error_message = "__partner__ placeholder must not remain in the rendered helm values."
  }

  assert {
    condition     = !strcontains(helm_release.apps["k8s-monitoring"].values[0], "__network__")
    error_message = "__network__ placeholder must not remain in the rendered helm values."
  }
}
