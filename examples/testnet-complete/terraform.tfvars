# ==============================================================================
# PLEASE NOTE the variables provided below, in conjunction with module defaults,
# make for a complete deployment.
#
# For additional info on available parameters, see root module variables.tf for
# full variable schema.
# ==============================================================================

# =============================================================================
#  Core
# =============================================================================
partner_name = "acme" # CHANGE ME: lowercase, used as a prefix in resource names
environment  = "testnet"
aws_region   = "eu-west-1" # CHANGE ME: AWS region to deploy into

default_tags = {
  Partner     = "acme" # CHANGE ME: match partner_name
  Environment = "testnet"
  ManagedBy   = "terraform"
}

# =============================================================================
#  Networking
# =============================================================================
networking = {
  enabled = true

  vpc = {
    cidr               = "10.1.0.0/16"                              # CHANGE ME: must not overlap with existing VPCs
    availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"] # CHANGE ME: match aws_region
    single_nat_gateway = true
  }
}

# =============================================================================
#  EKS
# =============================================================================
eks = {
  enabled = true

  cluster = {
    # Private-only by default — restrict endpoint_public_access_cidrs to your office / VPN IP range.
    endpoint_public_access       = true
    endpoint_public_access_cidrs = ["x.x.x.x/32"] # CHANGE ME: restrict to known IPs
  }

  node_groups = {
    groups = {
      default = {
        instance_types = ["t3.large"]
      }
    }
  }

  karpenter = {
    enabled          = true
    rule_name_prefix = "coproc"
  }
}

# =============================================================================
#  RDS (PostgreSQL)
# =============================================================================
rds = {
  enabled  = true
  db_name  = "coprocessor"
  username = "coprocessor"
}

# =============================================================================
#  k8s
# =============================================================================
k8s = {
  enabled           = true
  default_namespace = "coproc"

  namespaces = {
    coproc = {
      labels = {
        "app.kubernetes.io/name"       = "coprocessor"
        "app.kubernetes.io/component"  = "storage"
        "app.kubernetes.io/part-of"    = "zama-protocol"
        "app.kubernetes.io/managed-by" = "terraform"
      }
      annotations = {
        "terraform.io/module" = "coprocessor"
      }
    }
  }

  service_accounts = {
    coprocessor = {
      name      = "coprocessor"
      namespace = "coproc"
      s3_bucket_access = {
        coprocessor = { actions = ["s3:*Object", "s3:ListBucket"] }
      }
    }
  }

  storage_classes = {
    gp3 = {
      provisioner         = "ebs.csi.aws.com"
      reclaim_policy      = "Delete"
      volume_binding_mode = "WaitForFirstConsumer"
      parameters = {
        type      = "gp3"
        fsType    = "ext4"
        encrypted = "true"
      }
      annotations = {
        "storageclass.kubernetes.io/is-default-class" = "true"
      }
    }
  }

  external_name_services = {
    coprocessor-database = {
      # endpoint omitted — injected automatically from the rds submodule
      namespace = "coproc"
    }
  }
}

# =============================================================================
#  k8s Charts
# =============================================================================
k8s_charts = {
  enabled = true

  applications = {
    metrics-server = {
      namespace = {
        name   = "kube-system"
        create = false # kube-system already exists
      }

      helm_chart = {
        repository = "https://kubernetes-sigs.github.io/metrics-server"
        chart      = "metrics-server"
        version    = "3.13.0"
      }
    }

    karpenter = {
      namespace = {
        name   = "karpenter"
        create = true
      }

      service_account = {
        create = false # Let Helm chart create it
        name   = "karpenter"
      }

      helm_chart = {
        repository = "oci://public.ecr.aws/karpenter"
        chart      = "karpenter"
        version    = "1.8.2"

        # settings.clusterName, settings.interruptionQueue, and settings.eksControlPlane
        # are injected automatically from the eks submodule — no set block needed.

        values = <<-YAML
          logLevel: info

          replicas: 1
          dnsPolicy: Default

          # Pin the controller pod to the dedicated karpenter controller node group.
          nodeSelector:
            karpenter.sh/controller: "true"
          tolerations:
            - key: "karpenter.sh/controller"
              operator: "Equal"
              value: "true"
              effect: "NoSchedule"

          serviceAccount:
            create: true
            name: karpenter

          controller:
            resources:
              requests:
                cpu: 1
                memory: 1Gi
              limits:
                cpu: 1
                memory: 1Gi
            healthProbe:
              port: 8081
            startupProbe:
              httpGet:
                path: /healthz
                port: 8081
              initialDelaySeconds: 30
              periodSeconds: 10
              timeoutSeconds: 5
              failureThreshold: 18

          webhook:
            enabled: true
        YAML
      }
    }

    external-secrets = {
      namespace = {
        name   = "external-secrets"
        create = true
      }

      service_account = {
        create = true
        name   = "external-secrets"
        annotations = {
          "meta.helm.sh/release-name"      = "external-secrets"
          "meta.helm.sh/release-namespace" = "external-secrets"
        }
      }

      irsa = {
        enabled = true
        policy_statements = [
          {
            effect = "Allow"
            actions = [
              "secretsmanager:GetResourcePolicy",
              "secretsmanager:GetSecretValue",
              "secretsmanager:DescribeSecret",
              "secretsmanager:ListSecrets",
              "secretsmanager:ListSecretVersionIds",
            ]
            resources = ["*"] # CHANGE ME: restrict to specific secret ARNs for tighter scoping
          }
        ]
      }

      helm_chart = {
        repository = "https://charts.external-secrets.io"
        chart      = "external-secrets"
        version    = "2.2.0"

        values = <<-YAML
          installCRDs: true
          replicaCount: 1
          serviceAccount:
            create: false  # created and annotated by terraform above
            name: external-secrets
        YAML
      }

      additional_manifests = {
        enabled = true
        manifests = {
          cluster-secret-store = <<-YAML
            apiVersion: external-secrets.io/v1
            kind: ClusterSecretStore
            metadata:
              name: aws-secrets-manager
            spec:
              provider:
                aws:
                  service: SecretsManager
                  region: __region__
                  auth:
                    jwt:
                      serviceAccountRef:
                        name: external-secrets
                        namespace: external-secrets
          YAML
        }
      }
    }
  }
}

# =============================================================================
#  S3
# =============================================================================
s3 = {
  buckets = {
    coprocessor = {
      purpose = "coprocessor-storage"

      public_access = {
        enabled = true
      }

      cors = {
        enabled         = true
        allowed_origins = ["*"]
        allowed_methods = ["GET", "HEAD"]
        allowed_headers = ["Authorization"]
        expose_headers  = ["Access-Control-Allow-Origin"]
      }

      policy_statements = [
        {
          sid        = "PublicRead"
          effect     = "Allow"
          principals = { "*" = ["*"] }
          actions    = ["s3:GetObject"]
          resources  = ["objects"]
        },
        {
          sid        = "ZamaList"
          effect     = "Allow"
          principals = { "*" = ["*"] }
          actions    = ["s3:ListBucket"]
          resources  = ["bucket"]
        }
      ]
    }
  }
}
