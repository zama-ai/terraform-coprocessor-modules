# ***************************************
#  Data
# ***************************************
data "aws_region" "current" {}

# ***************************************
#  Locals
# ***************************************
locals {
  oidc_provider_id = replace(var.oidc_provider_arn, "/^.*oidc-provider\\//", "")

  namespace_apps = {
    for key, app in var.applications : key => app
    if app.namespace.create
  }

  service_account_apps = {
    for key, app in var.applications : key => app
    if app.service_account != null && app.service_account.create
  }

  irsa_apps = {
    for key, app in var.applications : key => app
    if app.irsa.enabled
  }

  helm_apps = {
    for key, app in var.applications : key => app
    if app.helm_chart != null && app.helm_chart.enabled
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
    for key, app in var.applications : key => app
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

  values = each.value.helm_chart.values != "" ? [each.value.helm_chart.values] : []

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

  values = each.value.helm_chart.values != "" ? [each.value.helm_chart.values] : []

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
