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

    controller_nodegroup = {
      enabled        = true
      instance_types = ["t3.small"]
    }
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
#  S3
# =============================================================================
s3 = {
  buckets = {
    coprocessor = {
      purpose = "coprocessor-storage"

      public_access = {
        enabled = true
      }

      cloudfront = {
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

# =============================================================================
#  k8s Coprocessor Dependencies
# =============================================================================
k8s_coprocessor_deps = {
  enabled           = true
  default_namespace = "coproc"

  namespaces = {
    coproc         = {}
    coproc-admin   = {}
    monitoring     = {}
    gw-blockchain  = {}
    eth-blockchain = {}
  }

  service_accounts = {
    coprocessor = {
      name      = "coprocessor"
      namespace = "coproc"
      s3_bucket_access = {
        coprocessor = { actions = ["s3:*Object", "s3:ListBucket"] }
      }
    }

    db-admin = {
      # Used by k8s Jobs/Pods that need superuser access to RDS:
      # pg_restore, CREATE USER, schema migrations, etc.
      name                     = "db-admin"
      namespace                = "coproc-admin"
      rds_master_secret_access = true
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
#  k8s System Charts
# =============================================================================
k8s_system_charts = {
  enabled = false

  applications = {
    karpenter-nodepools = {
      namespace = {
        name   = "karpenter"
        create = false # created by the karpenter helm release
      }

      additional_manifests = {
        enabled = false
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
              tags:
                karpenter.sh/discovery: __cluster_name__
          YAML

          # Compute-intensive pool for coprocessor workers (tfhe, zkproof, sns).
          # Tainted karpenter.sh/nodepool=coprocessor-pool:NoSchedule — worker pods must tolerate this.
          nodepool-coprocessor = <<-YAML
            apiVersion: karpenter.sh/v1
            kind: NodePool
            metadata:
              name: coprocessor-pool
            spec:
              template:
                spec:
                  nodeClassRef:
                    group: karpenter.k8s.aws
                    kind: EC2NodeClass
                    name: default
                  taints:
                    - key: karpenter.sh/nodepool
                      value: coprocessor-pool
                      effect: NoSchedule
                  requirements:
                    - key: karpenter.sh/capacity-type
                      operator: In
                      values: ["on-demand"]
                    - key: kubernetes.io/arch
                      operator: In
                      values: ["amd64"]
                    - key: node.kubernetes.io/instance-type
                      operator: In
                      values: ["c5.xlarge", "c5.2xlarge", "c5a.xlarge", "c5a.2xlarge"]
              limits:
                cpu: "100"
                memory: 400Gi
              disruption:
                consolidationPolicy: WhenEmpty
                consolidateAfter: 30s
          YAML

          # General-purpose pool for coprocessor services (db-migration, listeners, tx-sender).
          # Tainted karpenter.sh/nodepool=zws-pool:NoSchedule — service pods must tolerate this.
          nodepool-services = <<-YAML
            apiVersion: karpenter.sh/v1
            kind: NodePool
            metadata:
              name: zws-pool
            spec:
              template:
                spec:
                  nodeClassRef:
                    group: karpenter.k8s.aws
                    kind: EC2NodeClass
                    name: default
                  taints:
                    - key: karpenter.sh/nodepool
                      value: zws-pool
                      effect: NoSchedule
                  requirements:
                    - key: karpenter.sh/capacity-type
                      operator: In
                      values: ["on-demand"]
                    - key: kubernetes.io/arch
                      operator: In
                      values: ["amd64"]
                    - key: node.kubernetes.io/instance-type
                      operator: In
                      values: ["t3.large", "t3.xlarge", "m5.large", "m5.xlarge"]
              limits:
                cpu: "50"
                memory: 200Gi
              disruption:
                consolidationPolicy: WhenEmptyOrUnderutilized
                consolidateAfter: 1m
          YAML
        }
      }
    }

    prometheus-operator-crds = {
      # Cluster-scoped CRDs required by coprocessor app ServiceMonitors and the exporters.
      # Must be applied before any chart that creates ServiceMonitor resources.
      namespace = {
        name   = "monitoring"
        create = false # created by k8s-monitoring
      }

      helm_chart = {
        repository = "https://prometheus-community.github.io/helm-charts"
        chart      = "prometheus-operator-crds"
        version    = "28.0.1"
        crd_chart  = true  # Deployed before all other helm releases; ServiceMonitor charts depend on these CRDs
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
        create = false
      }

      helm_chart = {
        repository = "https://grafana.github.io/helm-charts"
        chart      = "k8s-monitoring"
        version    = "3.8.1"

        values = <<-YAML
          global:
            scrapeInterval: 10m

          alloy-metrics:
            enabled: true

          alloy-logs:
            enabled: true

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

          traces:
            enabled: true

          receivers:
            otlp:
              enabled: true
              grpc:
                enabled: true
                port: 4317
              http:
                enabled: false

          # __partner__ and __network__ are substituted automatically by the module
          # from var.partner_name and var.environment at apply time.
          destinations:
            - name: grafana-cloud-metrics
              type: prometheus
              url: # CHANGE ME
              externalLabels:
                partner: __partner__
                network: __network__
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
              url: # CHANGE ME
              tenantIdKey: loki-username
              externalLabels:
                partner: __partner__
                network: __network__
              auth:
                type: basic
                usernameKey: loki-username
                passwordKey: loki-password
              secret:
                create: false
                name: grafana-cloud-credentials
                namespace: monitoring

            - name: grafana-cloud-traces
              type: otlp
              url: # CHANGE ME
              protocol: http  # Grafana Cloud OTLP gateway requires http, not grpc (default)
              externalLabels:
                partner: __partner__
                network: __network__
              auth:
                type: basic
                usernameKey: otlp-username
                passwordKey: otlp-password
              secret:
                create: false
                name: grafana-cloud-credentials
                namespace: monitoring
        YAML
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
        version    = "1.0.1"

        values = <<-YAML
          irsa:
            create: false  # managed by terraform above

          prometheus-rds-exporter-chart:
            enabled: true
            replicaCount: 1
            resources:
              requests:
                cpu: 100m
                memory: 128Mi
              limits:
                cpu: 500m
                memory: 256Mi
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
