mock_provider "helm" {}

# Shared defaults across all runs.
variables {
  partner_name = "acme"
  environment  = "testnet"
}

# =============================================================================
#  No applications
# =============================================================================

run "empty_applications_creates_no_releases" {
  command = plan

  variables {
    applications = {}
  }

  assert {
    condition     = length(helm_release.this) == 0
    error_message = "No helm releases must be created when applications is empty."
  }
}

# =============================================================================
#  Release count and naming
# =============================================================================

run "one_release_per_map_entry" {
  command = plan

  variables {
    applications = {
      metrics-server = {
        repository = "https://kubernetes-sigs.github.io/metrics-server"
        chart      = "metrics-server"
        version    = "3.13.0"
        namespace  = "kube-system"
      }
      karpenter = {
        repository = "oci://public.ecr.aws/karpenter"
        chart      = "karpenter"
        version    = "1.8.2"
        namespace  = "karpenter"
      }
    }
  }

  assert {
    condition     = length(helm_release.this) == 2
    error_message = "One helm release must be created per applications map entry."
  }
}

run "release_name_matches_map_key" {
  command = plan

  variables {
    applications = {
      metrics-server = {
        repository = "https://kubernetes-sigs.github.io/metrics-server"
        chart      = "metrics-server"
        version    = "3.13.0"
        namespace  = "kube-system"
      }
    }
  }

  assert {
    condition     = helm_release.this["metrics-server"].name == "metrics-server"
    error_message = "Helm release name must match the map key."
  }
}

# =============================================================================
#  Namespace
# =============================================================================

run "release_namespace_matches_configuration" {
  command = plan

  variables {
    applications = {
      karpenter = {
        repository = "oci://public.ecr.aws/karpenter"
        chart      = "karpenter"
        version    = "1.8.2"
        namespace  = "karpenter"
      }
    }
  }

  assert {
    condition     = helm_release.this["karpenter"].namespace == "karpenter"
    error_message = "Helm release namespace must match the configured namespace."
  }
}

run "create_namespace_false_is_respected" {
  command = plan

  variables {
    applications = {
      metrics-server = {
        repository       = "https://kubernetes-sigs.github.io/metrics-server"
        chart            = "metrics-server"
        version          = "3.13.0"
        namespace        = "kube-system"
        create_namespace = false
      }
    }
  }

  assert {
    condition     = helm_release.this["metrics-server"].create_namespace == false
    error_message = "create_namespace = false must be passed through to the helm release."
  }
}

# =============================================================================
#  Chart coordinates
# =============================================================================

run "chart_repository_and_version_are_set" {
  command = plan

  variables {
    applications = {
      metrics-server = {
        repository = "https://kubernetes-sigs.github.io/metrics-server"
        chart      = "metrics-server"
        version    = "3.13.0"
        namespace  = "kube-system"
      }
    }
  }

  assert {
    condition     = helm_release.this["metrics-server"].repository == "https://kubernetes-sigs.github.io/metrics-server"
    error_message = "Helm release repository must match the configured value."
  }

  assert {
    condition     = helm_release.this["metrics-server"].version == "3.13.0"
    error_message = "Helm release version must match the configured value."
  }
}
