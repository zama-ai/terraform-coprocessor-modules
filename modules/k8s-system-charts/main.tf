# ***************************************
#  Data
# ***************************************
data "aws_region" "current" {}

# ***************************************
#  Locals
# ***************************************
locals {
  oidc_provider_id = replace(var.oidc_provider_arn, "/^.*oidc-provider\\//", "")

  # ── Baked-in Helm values strings ────────────────────────────────────────────
  karpenter_base_values = <<-YAML
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

  k8s_monitoring_base_values = <<-YAML
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
  YAML

  prometheus_rds_exporter_base_values = <<-YAML
    irsa:
      create: false

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

  prometheus_postgres_exporter_base_values = <<-YAML
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

    config:
      datasourceSecret:
        name: postgres-exporter-config
        key: DATA_SOURCE_NAME

    prometheusRule:
      enabled: false
  YAML

  # ── Baked-in manifests for karpenter-nodepools ───────────────────────────────
  karpenter_ec2nodeclass = <<-YAML
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

  karpenter_nodepool_coprocessor = <<-YAML
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

  karpenter_nodepool_services = <<-YAML
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

  # ── Built-in application objects ─────────────────────────────────────────────
  # Each object uses all fields explicitly so merge() produces a consistent type.
  builtin_karpenter_nodepools = {
    namespace       = { name = "karpenter", create = false }
    service_account = null
    irsa            = { enabled = false, role_name = null, policy_statements = [] }
    helm_chart      = null
    additional_manifests = {
      enabled = true
      manifests = {
        ec2nodeclass         = local.karpenter_ec2nodeclass
        nodepool-coprocessor = local.karpenter_nodepool_coprocessor
        nodepool-services    = local.karpenter_nodepool_services
      }
    }
  }

  builtin_prometheus_operator_crds = {
    namespace            = { name = "monitoring", create = false }
    service_account      = null
    irsa                 = { enabled = false, role_name = null, policy_statements = [] }
    additional_manifests = { enabled = false, manifests = {} }
    helm_chart = {
      enabled          = true
      repository       = "https://prometheus-community.github.io/helm-charts"
      chart            = "prometheus-operator-crds"
      version          = var.defaults.prometheus_operator_crds.version
      crd_chart        = true
      atomic           = false
      create_namespace = false
      wait             = true
      timeout          = 300
      values           = ""
      set              = {}
    }
  }

  builtin_metrics_server = {
    namespace            = { name = "kube-system", create = false }
    service_account      = null
    irsa                 = { enabled = false, role_name = null, policy_statements = [] }
    additional_manifests = { enabled = false, manifests = {} }
    helm_chart = {
      enabled          = true
      repository       = "https://kubernetes-sigs.github.io/metrics-server"
      chart            = "metrics-server"
      version          = var.defaults.metrics_server.version
      crd_chart        = false
      atomic           = true
      create_namespace = false
      wait             = true
      timeout          = 300
      values           = ""
      set              = {}
    }
  }

  builtin_karpenter = {
    namespace            = { name = "karpenter", create = true }
    service_account      = { create = false, name = "karpenter", labels = {}, annotations = {} }
    irsa                 = { enabled = false, role_name = null, policy_statements = [] }
    additional_manifests = { enabled = false, manifests = {} }
    helm_chart = {
      enabled          = true
      repository       = "oci://public.ecr.aws/karpenter"
      chart            = "karpenter"
      version          = var.defaults.karpenter.version
      crd_chart        = false
      atomic           = true
      create_namespace = false
      wait             = true
      timeout          = 300
      set              = {}
      values           = join("\n", compact([local.karpenter_base_values, var.defaults.karpenter.values]))
    }
  }

  # __partner__ and __network__ placeholders are substituted by resolved_helm_values.
  k8s_monitoring_destinations_values = <<-YAML
    destinations:
      - name: grafana-cloud-metrics
        type: prometheus
        url: ${var.defaults.k8s_monitoring.prometheus_url}
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
        url: ${var.defaults.k8s_monitoring.loki_url}
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
        url: ${var.defaults.k8s_monitoring.otlp_url}
        protocol: http
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

  builtin_k8s_monitoring = {
    namespace            = { name = "monitoring", create = false }
    service_account      = null
    irsa                 = { enabled = false, role_name = null, policy_statements = [] }
    additional_manifests = { enabled = false, manifests = {} }
    helm_chart = {
      enabled          = true
      repository       = "https://grafana.github.io/helm-charts"
      chart            = "k8s-monitoring"
      version          = var.defaults.k8s_monitoring.version
      crd_chart        = false
      atomic           = true
      create_namespace = false
      wait             = true
      timeout          = 300
      set              = {}
      values           = join("\n", compact([local.k8s_monitoring_base_values, local.k8s_monitoring_destinations_values, var.defaults.k8s_monitoring.values]))
    }
  }

  builtin_prometheus_rds_exporter = {
    namespace       = { name = "monitoring", create = false }
    service_account = { create = true, name = "prometheus-rds-exporter", labels = {}, annotations = {} }
    irsa = {
      enabled   = true
      role_name = null
      policy_statements = [
        { sid = "", effect = "Allow", actions = ["tag:GetResources"], resources = ["*"] },
        { sid = "", effect = "Allow", actions = ["rds:DescribeDBInstances", "rds:DescribeDBLogFiles"], resources = ["arn:aws:rds:*:*:db:*"] },
        { sid = "", effect = "Allow", actions = ["rds:DescribeDBClusters"], resources = ["arn:aws:rds:*:*:cluster:*"] },
        { sid = "", effect = "Allow", actions = ["rds:DescribePendingMaintenanceActions"], resources = ["*"] },
        { sid = "", effect = "Allow", actions = ["rds:DescribeAccountAttributes"], resources = ["*"] },
        { sid = "", effect = "Allow", actions = ["cloudwatch:GetMetricData"], resources = ["*"] },
        { sid = "", effect = "Allow", actions = ["servicequotas:GetServiceQuota"], resources = ["*"] },
        { sid = "", effect = "Allow", actions = ["ec2:DescribeInstanceTypes"], resources = ["*"] },
      ]
    }
    additional_manifests = { enabled = false, manifests = {} }
    helm_chart = {
      enabled          = true
      repository       = "oci://hub.zama.org/ghcr/zama-zws/helm-charts"
      chart            = "prometheus-rds-exporter"
      version          = var.defaults.prometheus_rds_exporter.version
      crd_chart        = false
      atomic           = true
      create_namespace = false
      wait             = true
      timeout          = 300
      set              = {}
      values           = local.prometheus_rds_exporter_base_values
    }
  }

  builtin_prometheus_postgres_exporter = {
    namespace            = { name = "monitoring", create = false }
    service_account      = null
    irsa                 = { enabled = false, role_name = null, policy_statements = [] }
    additional_manifests = { enabled = false, manifests = {} }
    helm_chart = {
      enabled          = true
      repository       = "https://prometheus-community.github.io/helm-charts"
      chart            = "prometheus-postgres-exporter"
      version          = var.defaults.prometheus_postgres_exporter.version
      crd_chart        = false
      atomic           = true
      create_namespace = false
      wait             = true
      timeout          = 300
      set              = {}
      values           = local.prometheus_postgres_exporter_base_values
    }
  }

  # ── Merged applications map ──────────────────────────────────────────────────
  # extra entries with the same key as a built-in override the built-in entirely.
  applications = merge(
    var.defaults.karpenter_nodepools.enabled ? { karpenter-nodepools = local.builtin_karpenter_nodepools } : {},
    var.defaults.prometheus_operator_crds.enabled ? { prometheus-operator-crds = local.builtin_prometheus_operator_crds } : {},
    var.defaults.metrics_server.enabled ? { metrics-server = local.builtin_metrics_server } : {},
    var.defaults.karpenter.enabled ? { karpenter = local.builtin_karpenter } : {},
    var.defaults.k8s_monitoring.enabled ? { k8s-monitoring = local.builtin_k8s_monitoring } : {},
    var.defaults.prometheus_rds_exporter.enabled ? { prometheus-rds-exporter = local.builtin_prometheus_rds_exporter } : {},
    var.defaults.prometheus_postgres_exporter.enabled ? { prometheus-postgres-exporter = local.builtin_prometheus_postgres_exporter } : {},
    var.extra,
  )

  namespace_apps = {
    for key, app in local.applications : key => app
    if app.namespace.create
  }

  service_account_apps = {
    for key, app in local.applications : key => app
    if app.service_account != null && app.service_account.create
  }

  irsa_apps = {
    for key, app in local.applications : key => app
    if app.irsa.enabled
  }

  helm_apps = {
    for key, app in local.applications : key => app
    if app.helm_chart != null && app.helm_chart.enabled
  }

  # Substitute standard placeholders in helm values so that computed or
  # partner-specific values can be embedded directly in the tfvars YAML block
  # without requiring root-level set_computed overrides.
  #
  # Supported placeholders:
  #   __partner__ → var.partner_name
  #   __network__ → var.environment
  resolved_helm_values = {
    for key, app in local.helm_apps : key => replace(
      replace(app.helm_chart.values, "__partner__", var.partner_name),
      "__network__", var.environment
    )
  }

  # CRD-only releases are deployed first; all other releases depend on them.
  crd_helm_apps = {
    for key, app in local.helm_apps : key => app
    if app.helm_chart.crd_chart
  }

  app_helm_apps = {
    for key, app in local.helm_apps : key => app
    if !app.helm_chart.crd_chart
  }

  manifests_apps = {
    for key, app in local.applications : key => app
    if app.additional_manifests.enabled
  }

  # IRSA role ARN annotation, keyed by app name. Merged into SA annotations automatically.
  irsa_role_annotations = {
    for key, role in aws_iam_role.irsa :
    key => { "eks.amazonaws.com/role-arn" = role.arn }
  }
}

# ***************************************
#  Namespaces
# ***************************************
resource "kubernetes_namespace" "this" {
  for_each = local.namespace_apps

  metadata {
    name = each.value.namespace.name
  }
}

# ***************************************
#  Service Accounts
# ***************************************
resource "kubernetes_service_account" "this" {
  for_each = local.service_account_apps

  metadata {
    name      = each.value.service_account.name
    namespace = each.value.namespace.name
    labels    = each.value.service_account.labels
    annotations = merge(
      each.value.service_account.annotations,
      lookup(local.irsa_role_annotations, each.key, {}),
    )
  }

  depends_on = [kubernetes_namespace.this, aws_iam_role_policy_attachment.irsa]
}

# ***************************************
#  IRSA
# ***************************************
data "aws_iam_policy_document" "irsa_assume_role" {
  for_each = local.irsa_apps

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_id}:sub"
      values   = ["system:serviceaccount:${each.value.namespace.name}:${try(each.value.service_account.name, each.key)}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_id}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "irsa" {
  for_each = local.irsa_apps

  dynamic "statement" {
    for_each = each.value.irsa.policy_statements
    iterator = stmt

    content {
      sid       = stmt.value.sid
      effect    = stmt.value.effect
      actions   = stmt.value.actions
      resources = stmt.value.resources
    }
  }
}

resource "aws_iam_role" "irsa" {
  for_each = local.irsa_apps

  name               = coalesce(each.value.irsa.role_name, "${each.key}-${var.partner_name}-${var.environment}")
  assume_role_policy = data.aws_iam_policy_document.irsa_assume_role[each.key].json
}

resource "aws_iam_policy" "irsa" {
  for_each = local.irsa_apps

  name   = coalesce(each.value.irsa.role_name, "${each.key}-${var.partner_name}-${var.environment}")
  policy = data.aws_iam_policy_document.irsa[each.key].json
}

resource "aws_iam_role_policy_attachment" "irsa" {
  for_each = local.irsa_apps

  role       = aws_iam_role.irsa[each.key].name
  policy_arn = aws_iam_policy.irsa[each.key].arn
}

# ***************************************
#  Helm Releases — CRDs first
# ***************************************
resource "helm_release" "crds" {
  for_each = local.crd_helm_apps

  name             = each.key
  repository       = each.value.helm_chart.repository
  chart            = each.value.helm_chart.chart
  version          = each.value.helm_chart.version
  namespace        = each.value.namespace.name
  create_namespace = each.value.helm_chart.create_namespace
  atomic           = each.value.helm_chart.atomic
  wait             = each.value.helm_chart.wait
  timeout          = each.value.helm_chart.timeout

  values = local.resolved_helm_values[each.key] != "" ? [local.resolved_helm_values[each.key]] : []

  set = [for key, value in merge(
    each.value.helm_chart.set,
    lookup(var.set_computed, each.key, {}),
  ) : { name = key, value = value }]

  depends_on = [kubernetes_namespace.this, kubernetes_service_account.this, aws_iam_role_policy_attachment.irsa]
}

# ***************************************
#  Helm Releases — Applications
# ***************************************
resource "helm_release" "apps" {
  for_each = local.app_helm_apps

  name             = each.key
  repository       = each.value.helm_chart.repository
  chart            = each.value.helm_chart.chart
  version          = each.value.helm_chart.version
  namespace        = each.value.namespace.name
  create_namespace = each.value.helm_chart.create_namespace
  atomic           = each.value.helm_chart.atomic
  wait             = each.value.helm_chart.wait
  timeout          = each.value.helm_chart.timeout

  values = local.resolved_helm_values[each.key] != "" ? [local.resolved_helm_values[each.key]] : []

  set = [for key, value in merge(
    each.value.helm_chart.set,
    lookup(var.set_computed, each.key, {}),
  ) : { name = key, value = value }]

  depends_on = [kubernetes_namespace.this, kubernetes_service_account.this, aws_iam_role_policy_attachment.irsa, helm_release.crds]
}

# ***************************************
#  Additional Manifests
# ***************************************
resource "kubernetes_manifest" "additional" {
  for_each = merge([
    for app_key, app in local.manifests_apps : {
      for name, yaml in app.additional_manifests.manifests :
      "${app_key}/${name}" => yamldecode(
        replace(
          replace(
            replace(yaml, "__region__", data.aws_region.current.id),
            "__cluster_name__", var.manifests_vars.cluster_name
          ),
          "__node_role__", var.manifests_vars.node_role
        )
      )
    }
  ]...)

  manifest   = each.value
  depends_on = [helm_release.crds, helm_release.apps]
}
