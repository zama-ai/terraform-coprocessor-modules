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
# Disable the four built-ins that default to enabled so that existing tests
# using `extra` can make precise count assertions without interference.
variables {
  partner_name      = "acme"
  environment       = "testnet"
  oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLE1234567890"
  defaults = {
    karpenter_nodepools      = { enabled = false }
    prometheus_operator_crds = { enabled = false }
    metrics_server           = { enabled = false }
    karpenter                = { enabled = false }
  }
}

# =============================================================================
#  No applications
# =============================================================================

run "empty_applications_creates_no_resources" {
  command = plan

  variables {
    extra = {}
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
    extra = {
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

# =============================================================================
#  Helm release
# =============================================================================

run "one_release_per_helm_app" {
  command = plan

  variables {
    extra = {
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

run "helm_release_skipped_when_helm_chart_disabled" {
  command = plan

  variables {
    extra = {
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
    extra = {
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
    extra = {
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

# =============================================================================
#  IRSA
# =============================================================================

run "irsa_enabled_creates_role_policy_and_attachment" {
  command = plan

  variables {
    extra = {
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
    extra = {
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
    extra = {
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

run "manifests_vars_placeholders_are_substituted" {
  command = plan

  variables {
    manifests_vars = {
      cluster_name = "acme-testnet"
      node_role    = "acme-testnet-Karpenter"
    }
    extra = {
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
    extra = {
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

# =============================================================================
#  Built-in defaults — k8s_monitoring URL injection
# =============================================================================

run "defaults_k8s_monitoring_urls_injected_into_destinations" {
  command = plan

  variables {
    defaults = {
      karpenter_nodepools      = { enabled = false }
      prometheus_operator_crds = { enabled = false }
      metrics_server           = { enabled = false }
      karpenter                = { enabled = false }
      k8s_monitoring = {
        enabled                  = true
        prometheus_url           = "https://prometheus.example.com/push"
        loki_url                 = "https://loki.example.com/push"
        otlp_url                 = "https://otlp.example.com/push"
        alloy_operator_image_tag = "v9.9.1"
        alloy_image_tag          = "v9.9.2"
        node_exporter_image_tag  = "v9.9.3"
      }
    }
  }

  assert {
    condition     = strcontains(helm_release.apps["k8s-monitoring"].values[0], "https://prometheus.example.com/push")
    error_message = "prometheus_url must be injected into the base values fragment."
  }

  assert {
    condition     = strcontains(helm_release.apps["k8s-monitoring"].values[0], "https://loki.example.com/push")
    error_message = "loki_url must be injected into the base values fragment."
  }

  assert {
    condition     = strcontains(helm_release.apps["k8s-monitoring"].values[0], "https://otlp.example.com/push")
    error_message = "otlp_url must be injected into the base values fragment."
  }

  assert {
    condition     = strcontains(helm_release.apps["k8s-monitoring"].values[0], "partner: acme")
    error_message = "__partner__ placeholder in baked-in destinations must still be substituted."
  }

  assert {
    condition     = strcontains(helm_release.apps["k8s-monitoring"].values[0], "scrapeInterval: 10m")
    error_message = "Baked-in k8s_monitoring base values must include scrapeInterval: 10m."
  }

  assert {
    condition     = strcontains(helm_release.apps["k8s-monitoring"].values[0], "clusterMetrics")
    error_message = "Baked-in k8s_monitoring base values must be present in the first fragment."
  }

  assert {
    condition     = strcontains(helm_release.apps["k8s-monitoring"].values[0], "kube-state-metrics")
    error_message = "telemetryServices.kube-state-metrics must be present in the base values fragment."
  }

  assert {
    condition     = strcontains(helm_release.apps["k8s-monitoring"].values[0], "repository: zama-protocol/zama.ai/grafana-alloy-operator")
    error_message = "Baked-in k8s_monitoring values must set the alloy operator image repository."
  }

  assert {
    condition     = strcontains(helm_release.apps["k8s-monitoring"].values[0], "tag: v9.9.1")
    error_message = "alloy_operator_image_tag must be injected into the alloy operator image block."
  }

  assert {
    condition     = strcontains(helm_release.apps["k8s-monitoring"].values[0], "tag: v9.9.2")
    error_message = "alloy_image_tag must be injected into the collector image blocks."
  }

  assert {
    condition     = strcontains(helm_release.apps["k8s-monitoring"].values[0], "tag: v9.9.3")
    error_message = "node_exporter_image_tag must be injected into the node-exporter image block."
  }
}

# =============================================================================
#  Built-in defaults
# =============================================================================

run "defaults_karpenter_enabled_creates_helm_release" {
  command = plan

  variables {
    defaults = {
      karpenter_nodepools      = { enabled = false }
      prometheus_operator_crds = { enabled = false }
      metrics_server           = { enabled = false }
      karpenter                = { enabled = true }
    }
  }

  assert {
    condition     = contains(keys(helm_release.apps), "karpenter")
    error_message = "Built-in karpenter must create a helm_release.apps entry."
  }

  assert {
    condition     = helm_release.apps["karpenter"].chart == "karpenter"
    error_message = "Built-in karpenter chart name must be 'karpenter'."
  }

  assert {
    condition     = helm_release.apps["karpenter"].repository == "oci://public.ecr.aws/karpenter"
    error_message = "Built-in karpenter must use the public ECR repository."
  }
}

# Consolidates version, repository, and chart override tests into a single run.
run "defaults_karpenter_user_values_appended_to_base" {
  command = plan

  variables {
    defaults = {
      karpenter_nodepools      = { enabled = false }
      prometheus_operator_crds = { enabled = false }
      metrics_server           = { enabled = false }
      karpenter = {
        enabled              = true
        version              = "1.9.0"
        repository           = "oci://my-registry.example.com/karpenter"
        chart                = "karpenter-fork"
        controller_image_tag = "v9.9.9"
        values               = "replicas: 2\n"
      }
    }
  }

  assert {
    condition     = helm_release.apps["karpenter"].version == "1.9.0"
    error_message = "defaults.karpenter.version override must be respected."
  }

  assert {
    condition     = helm_release.apps["karpenter"].repository == "oci://my-registry.example.com/karpenter"
    error_message = "defaults.karpenter.repository override must be respected."
  }

  assert {
    condition     = helm_release.apps["karpenter"].chart == "karpenter-fork"
    error_message = "defaults.karpenter.chart override must be respected."
  }

  assert {
    condition     = strcontains(helm_release.apps["karpenter"].values[1], "replicas: 2")
    error_message = "User-supplied karpenter values must be present in the second fragment (after base)."
  }

  assert {
    condition     = strcontains(helm_release.apps["karpenter"].values[0], "logLevel: info")
    error_message = "Baked-in karpenter base values must still be present in the first fragment."
  }

  assert {
    condition     = strcontains(helm_release.apps["karpenter"].values[0], "repository: hub.zama.org/zama-protocol/zama.ai/karpenter")
    error_message = "Baked-in karpenter values must set the controller image repository."
  }

  assert {
    condition     = strcontains(helm_release.apps["karpenter"].values[0], "tag: v9.9.9")
    error_message = "controller_image_tag must be injected into the baked-in karpenter values."
  }
}

run "defaults_metrics_server_and_postgres_exporter_image_tags_are_injected" {
  command = plan

  variables {
    defaults = {
      karpenter_nodepools      = { enabled = false }
      prometheus_operator_crds = { enabled = false }
      metrics_server = {
        enabled   = true
        image_tag = "v9.8.7"
      }
      karpenter = { enabled = false }
      prometheus_postgres_exporter = {
        enabled   = true
        image_tag = "v7.8.9"
      }
    }
  }

  assert {
    condition     = strcontains(helm_release.apps["metrics-server"].values[0], "repository: hub.zama.org/zama-protocol/zama.ai/metrics-server")
    error_message = "Baked-in metrics-server values must set the image repository."
  }

  assert {
    condition     = strcontains(helm_release.apps["metrics-server"].values[0], "tag: v9.8.7")
    error_message = "metrics_server.image_tag must be injected into the baked-in values."
  }

  assert {
    condition     = strcontains(helm_release.apps["prometheus-postgres-exporter"].values[0], "repository: zama-protocol/zama.ai/prometheus-postgres-exporter")
    error_message = "Baked-in prometheus-postgres-exporter values must set the image repository."
  }

  assert {
    condition     = strcontains(helm_release.apps["prometheus-postgres-exporter"].values[0], "tag: v7.8.9")
    error_message = "prometheus_postgres_exporter.image_tag must be injected into the baked-in values."
  }
}

run "defaults_karpenter_nodepools_enabled_creates_three_manifests" {
  command = plan

  variables {
    manifests_vars = {
      cluster_name = "acme-testnet"
      node_role    = "acme-testnet-Karpenter"
    }
    defaults = {
      karpenter_nodepools      = { enabled = true }
      prometheus_operator_crds = { enabled = false }
      metrics_server           = { enabled = false }
      karpenter                = { enabled = false }
    }
  }

  assert {
    condition     = length(kubernetes_manifest.additional) == 3
    error_message = "Built-in karpenter-nodepools must create 3 manifests (ec2nodeclass + 2 nodepools)."
  }

  assert {
    condition     = contains(keys(kubernetes_manifest.additional), "karpenter-nodepools/ec2nodeclass")
    error_message = "Built-in karpenter-nodepools must include the ec2nodeclass manifest."
  }

  assert {
    condition     = contains(keys(kubernetes_manifest.additional), "karpenter-nodepools/nodepool-coprocessor")
    error_message = "Built-in karpenter-nodepools must include the nodepool-coprocessor manifest."
  }

  assert {
    condition     = contains(keys(kubernetes_manifest.additional), "karpenter-nodepools/nodepool-services")
    error_message = "Built-in karpenter-nodepools must include the nodepool-services manifest."
  }
}

run "defaults_prometheus_rds_exporter_enabled_creates_irsa" {
  command = plan

  variables {
    defaults = {
      karpenter_nodepools      = { enabled = false }
      prometheus_operator_crds = { enabled = false }
      metrics_server           = { enabled = false }
      karpenter                = { enabled = false }
      prometheus_rds_exporter  = { enabled = true }
    }
  }

  assert {
    condition     = contains(keys(aws_iam_role.irsa), "prometheus-rds-exporter")
    error_message = "Built-in prometheus-rds-exporter must create an IRSA role."
  }

  assert {
    condition     = contains(keys(helm_release.apps), "prometheus-rds-exporter")
    error_message = "Built-in prometheus-rds-exporter must create a helm release."
  }
}

run "extra_overrides_builtin_with_same_key" {
  command = plan

  variables {
    defaults = {
      karpenter_nodepools      = { enabled = false }
      prometheus_operator_crds = { enabled = false }
      metrics_server           = { enabled = true }
      karpenter                = { enabled = false }
    }
    extra = {
      metrics-server = {
        namespace  = { name = "kube-system" }
        helm_chart = { repository = "https://kubernetes-sigs.github.io/metrics-server", chart = "metrics-server", version = "9.9.9" }
      }
    }
  }

  assert {
    condition     = helm_release.apps["metrics-server"].version == "9.9.9"
    error_message = "extra entry must override the built-in when keys match."
  }

  assert {
    condition     = length(helm_release.apps) == 1
    error_message = "extra override must not create a duplicate release alongside the built-in."
  }
}
