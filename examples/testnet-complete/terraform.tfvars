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
    prometheus-operator-crds = {
      # Cluster-scoped CRDs required by coprocessor app ServiceMonitors and the exporters.
      # Must be applied before any chart that creates ServiceMonitor resources.
      # NOTE: on a net-new cluster, apply this first or accept a two-phase apply.
      namespace = {
        name   = "monitoring"
        create = false # created by k8s-monitoring
      }

      helm_chart = {
        repository = "https://prometheus-community.github.io/helm-charts"
        chart      = "prometheus-operator-crds"
        version    = "28.0.1"
        atomic     = false # CRDs are cluster-scoped; atomic rollback is not dangerous here
      }
    }

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
        create = false
        name   = "karpenter"
      }

      helm_chart = {
        repository = "oci://public.ecr.aws/karpenter"
        chart      = "karpenter"
        version    = "1.8.2"

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

    k8s-monitoring = {
      namespace = {
        name   = "monitoring"
        create = true
      }

      helm_chart = {
        repository = "https://grafana.github.io/helm-charts"
        chart      = "k8s-monitoring"
        version    = "3.8.1"

        # Credentials must be created manually before first deploy:
        # kubectl create secret generic grafana-cloud-credentials -n monitoring \
        #   --from-literal=prometheus-username=<id> --from-literal=prometheus-password=<token> \
        #   --from-literal=loki-username=<id>       --from-literal=loki-password=<token>
        values = <<-YAML
          global:
            scrapeInterval: 5m  # CHANGE ME: increase to 10m to further reduce ingestion costs

          clusterMetrics:
            enabled: true

          prometheusOperatorObjects:
            enabled: true
            serviceMonitors:
              enabled: true
              namespaces:
                - monitoring
                - coproc
                - gw-blockchain
                - eth-blockchain
                - kube-system

          podLogs:
            enabled: true
            namespaces:
              - coproc
              - gw-blockchain
              - eth-blockchain

          destinations:
            - name: grafana-cloud-metrics
              type: prometheus
              auth:
                type: basic
                usernameKey: prometheus-username
                passwordKey: prometheus-password
              secret:
                create: false
                name: grafana-cloud-credentials
                namespace: monitoring

            - name: grafana-cloud-logs
              type: loki
              tenantIdKey: loki-username
              auth:
                type: basic
                usernameKey: loki-username
                passwordKey: loki-password
              secret:
                create: false
                name: grafana-cloud-credentials
                namespace: monitoring
        YAML

        set = {
          # CHANGE ME: your Grafana Cloud Prometheus remote_write URL
          "destinations[0].url" = "https://prometheus-prod-xx-yyyy.grafana.net/api/prom/push"
          # CHANGE ME: your Grafana Cloud Loki push URL
          "destinations[1].url" = "https://logs-prod-xx-yyyy.grafana.net/loki/api/v1/push"
        }
      }
    }

    prometheus-rds-exporter = {
      namespace = {
        name   = "monitoring"
        create = false # created by k8s-monitoring
      }

      service_account = {
        create = true
        name   = "prometheus-rds-exporter"
      }

      irsa = {
        enabled = true
        policy_statements = [
          {
            effect    = "Allow"
            actions   = ["tag:GetResources"]
            resources = ["*"]
          },
          {
            effect    = "Allow"
            actions   = ["rds:DescribeDBInstances", "rds:DescribeDBLogFiles"]
            resources = ["arn:aws:rds:*:*:db:*"]
          },
          {
            effect    = "Allow"
            actions   = ["rds:DescribeDBClusters"]
            resources = ["arn:aws:rds:*:*:cluster:*"]
          },
          {
            effect    = "Allow"
            actions   = ["rds:DescribePendingMaintenanceActions"]
            resources = ["*"]
          },
          {
            effect    = "Allow"
            actions   = ["rds:DescribeAccountAttributes"]
            resources = ["*"]
          },
          {
            effect    = "Allow"
            actions   = ["cloudwatch:GetMetricData"]
            resources = ["*"]
          },
          {
            effect    = "Allow"
            actions   = ["servicequotas:GetServiceQuota"]
            resources = ["*"]
          },
          {
            effect    = "Allow"
            actions   = ["ec2:DescribeInstanceTypes"]
            resources = ["*"]
          },
        ]
      }

      helm_chart = {
        repository = "oci://hub.zama.org/ghcr/zama-zws/helm-charts"
        chart      = "prometheus-rds-exporter"
        version    = "1.1.0"

        values = <<-YAML
          irsa:
            create: false  # managed by terraform above

          prometheus-rds-exporter-chart:
            enabled: true
            replicaCount: 1
            resources:
              requests:
                cpu: 1000m
                memory: 1000Mi
              limits:
                cpu: 1000m
                memory: 1000Mi
            serviceAccount:
              create: false
              name: prometheus-rds-exporter
            serviceMonitor:
              enabled: true
              relabelings:
                - action: replace
                  targetLabel: network
                  # replacement injected from var.environment via set_computed
            config:
              metrics-path: /metrics
              listen-address: ":9043"
              enable-otel-traces: false
              collect-instance-metrics: true
              collect-instance-tags: true
              collect-instance-types: true
              collect-logs-size: true
              collect-serverless-logs-size: false
              collect-maintenances: true
              collect-quotas: true
              collect-usages: true
        YAML
      }
    }

    prometheus-postgres-exporter = {
      namespace = {
        name   = "monitoring"
        create = false # created by k8s-monitoring
      }

      # kubectl create secret generic postgres-exporter-config -n monitoring \
      #   --from-literal=DATA_SOURCE_NAME="postgresql://coproc:<password>@coprocessor-database.coproc.svc.cluster.local:5432/coprocessor?sslmode=require"

      helm_chart = {
        repository = "https://prometheus-community.github.io/helm-charts"
        chart      = "prometheus-postgres-exporter"
        version    = "7.3.0"

        # network relabeling replacement injected from var.environment via set_computed.
        values = <<-YAML
          replicaCount: 1

          automountServiceAccountToken: false

          serviceAccount:
            create: true

          podSecurityContext:
            runAsGroup: 1001
            runAsUser: 1001
            runAsNonRoot: true
            seccompProfile:
              type: RuntimeDefault

          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
            privileged: false
            readOnlyRootFilesystem: true

          serviceMonitor:
            enabled: true
            relabelings:
              - action: replace
                targetLabel: network
                # replacement injected from var.environment via set_computed

          config:
            datasourceSecret:
              name: postgres-exporter-config
              key: DATA_SOURCE_NAME

          prometheusRule:
            enabled: false
        YAML
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
