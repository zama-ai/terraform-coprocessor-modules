# ***************************************
#  Locals
# ***************************************
locals {
  namespace = var.k8s.default_namespace

  # Strip the ARN prefix to get the bare issuer hostname used as the OIDC condition key
  # e.g., "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
  #     → "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
  oidc_provider_id = replace(var.oidc_provider_arn, "/^.*oidc-provider\\//", "")

}

# ***************************************
#  Storage Classes
# ***************************************
resource "kubernetes_storage_class_v1" "this" {
  for_each = var.k8s.enabled ? var.k8s.storage_classes : {}

  metadata {
    name        = each.key
    annotations = each.value.annotations
    labels      = each.value.labels
  }

  storage_provisioner    = each.value.provisioner
  reclaim_policy         = each.value.reclaim_policy
  volume_binding_mode    = each.value.volume_binding_mode
  allow_volume_expansion = each.value.allow_volume_expansion
  parameters             = each.value.parameters
}

# ***************************************
#  Kubernetes Namespaces
# ***************************************
resource "kubernetes_namespace" "this" {
  for_each = var.k8s.enabled ? var.k8s.namespaces : {}

  metadata {
    name = each.key

    labels = merge({
      "app.kubernetes.io/name"       = "coprocessor"
      "app.kubernetes.io/component"  = "namespace"
      "app.kubernetes.io/part-of"    = "zama-protocol"
      "app.kubernetes.io/managed-by" = "terraform"
    }, each.value.labels)

    annotations = merge({
      "terraform.io/module" = "k8s"
    }, each.value.annotations)
  }
}

# ***************************************
#  IAM: per-service-account policy + IRSA role
# ***************************************
data "aws_iam_policy_document" "service_account" {
  for_each = var.k8s.enabled ? var.k8s.service_accounts : {}

  dynamic "statement" {
    for_each = each.value.iam_policy_statements

    content {
      sid       = statement.value.sid
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources

      dynamic "condition" {
        for_each = statement.value.conditions

        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}

data "aws_iam_policy_document" "service_account_assume_role" {
  for_each = var.k8s.enabled ? var.k8s.service_accounts : {}

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
      values   = ["system:serviceaccount:${coalesce(each.value.namespace, local.namespace)}:${each.value.name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_id}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "service_account" {
  for_each = var.k8s.enabled ? var.k8s.service_accounts : {}

  name   = coalesce(each.value.iam_role_name_override, "${each.key}-${var.partner_name}-${var.environment}")
  policy = data.aws_iam_policy_document.service_account[each.key].json
}

resource "aws_iam_role" "service_account" {
  for_each = var.k8s.enabled ? var.k8s.service_accounts : {}

  name               = coalesce(each.value.iam_role_name_override, "${each.key}-${var.partner_name}-${var.environment}")
  assume_role_policy = data.aws_iam_policy_document.service_account_assume_role[each.key].json
}

resource "aws_iam_role_policy_attachment" "service_account" {
  for_each = var.k8s.enabled ? var.k8s.service_accounts : {}

  role       = aws_iam_role.service_account[each.key].name
  policy_arn = aws_iam_policy.service_account[each.key].arn
}

# ***************************************
#  Kubernetes Service Accounts
# ***************************************
resource "kubernetes_service_account" "this" {
  for_each = var.k8s.enabled ? var.k8s.service_accounts : {}

  metadata {
    name      = each.value.name
    namespace = coalesce(each.value.namespace, local.namespace)

    labels = merge({
      "app.kubernetes.io/name"       = "coprocessor"
      "app.kubernetes.io/component"  = "service-account"
      "app.kubernetes.io/part-of"    = "zama-protocol"
      "app.kubernetes.io/managed-by" = "terraform"
    }, each.value.labels)

    annotations = merge(
      { "terraform.io/module" = "k8s" },
      { "eks.amazonaws.com/role-arn" = aws_iam_role.service_account[each.key].arn },
      each.value.annotations,
    )
  }

  depends_on = [kubernetes_namespace.this, aws_iam_role_policy_attachment.service_account]
}

# ***************************************
#  ExternalName Services (RDS, ElastiCache, etc.)
# ***************************************
resource "kubernetes_service" "external_name" {
  for_each = var.k8s.enabled ? var.k8s.external_name_services : {}

  metadata {
    name        = each.key
    namespace   = coalesce(each.value.namespace, local.namespace)
    annotations = each.value.annotations
  }

  spec {
    type          = "ExternalName"
    external_name = split(":", each.value.endpoint)[0]
  }

  depends_on = [kubernetes_namespace.this]
}
