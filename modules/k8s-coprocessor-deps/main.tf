# ***************************************
#  Locals
# ***************************************
locals {
  namespace = var.k8s.default_namespace

  # Strip the ARN prefix to get the bare issuer hostname used as the OIDC condition key
  # e.g., "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
  #     → "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
  oidc_provider_id = replace(var.oidc_provider_arn, "/^.*oidc-provider\\//", "")

  # ── Built-in service accounts ──────────────────────────────────────────────
  builtin_sns_worker_sa = {
    name      = "sns-worker"
    namespace = local.namespace
    s3_bucket_access = {
      (var.k8s.service_accounts.sns_worker.s3_bucket_key) = { actions = ["s3:*Object", "s3:ListBucket"] }
    }
    rds_master_secret_access = false
    kms_key_access           = false
    iam_role_name_override   = null
    iam_policy_statements    = []
    labels                   = {}
    annotations              = {}
  }

  builtin_db_admin_sa = {
    name                     = "db-admin"
    namespace                = "coproc-admin"
    s3_bucket_access         = {}
    rds_master_secret_access = true
    kms_key_access           = false
    iam_role_name_override   = null
    iam_policy_statements    = []
    labels                   = {}
    annotations              = {}
  }

  builtin_tx_sender_sa = {
    name                     = "tx-sender"
    namespace                = "gw-blockchain"
    s3_bucket_access         = {}
    rds_master_secret_access = false
    kms_key_access           = var.k8s.service_accounts.tx_sender.kms_key_access
    iam_role_name_override   = null
    iam_policy_statements    = []
    labels                   = {}
    annotations              = {}
  }

  # ── Built-in storage classes ───────────────────────────────────────────────
  builtin_gp3 = {
    provisioner            = "ebs.csi.aws.com"
    reclaim_policy         = "Delete"
    volume_binding_mode    = "WaitForFirstConsumer"
    allow_volume_expansion = true
    parameters = {
      type      = "gp3"
      fsType    = "ext4"
      encrypted = "true"
    }
    annotations = { "storageclass.kubernetes.io/is-default-class" = "true" }
    labels      = {}
  }

  # ── Merged maps — extra entries with the same key override the built-in ────
  service_accounts = merge(
    var.k8s.service_accounts.sns_worker.enabled ? { sns-worker = local.builtin_sns_worker_sa } : {},
    var.k8s.service_accounts.db_admin.enabled ? { db-admin = local.builtin_db_admin_sa } : {},
    var.k8s.service_accounts.tx_sender.enabled ? { tx-sender = local.builtin_tx_sender_sa } : {},
    var.k8s.service_accounts.extra,
  )

  storage_classes = merge(
    var.k8s.storage_classes.gp3.enabled ? { gp3 = local.builtin_gp3 } : {},
    var.k8s.storage_classes.extra,
  )

  # ── Common labels applied to every Kubernetes resource ────────────────────
  common_labels = {
    "app.kubernetes.io/name"       = "coprocessor"
    "app.kubernetes.io/part-of"    = "zama-protocol"
    "app.kubernetes.io/managed-by" = "terraform"
  }

  # ── SecurityGroupPolicy expansion ─────────────────────────────────────────
  # Built-in rds_client policy: one SecurityGroupPolicy per listed namespace,
  # attaching the rds-client SG to any pod whose template carries the
  # configured opt-in label. The for_each map keys depend only on statically
  # known inputs (the namespaces list) so plan can determine instance keys
  # without waiting for the SG ID to be known. The SG ID null check is
  # enforced via a resource-level precondition below.
  rds_client_policies = (
    var.k8s.enabled
    && var.k8s.security_group_policies.rds_client.enabled
    ) ? {
    for ns in var.k8s.security_group_policies.rds_client.namespaces :
    "rds-client-${ns}" => {
      name      = "rds-client"
      namespace = ns
      pod_selector = {
        (var.k8s.security_group_policies.rds_client.pod_label_key) = var.k8s.security_group_policies.rds_client.pod_label_value
      }
      security_group_ids = [var.rds_client_security_group_id]
    }
  } : {}

  security_group_policies = merge(
    local.rds_client_policies,
    {
      for key, cfg in var.k8s.security_group_policies.extra :
      key => {
        name               = key
        namespace          = cfg.namespace
        pod_selector       = cfg.pod_selector
        security_group_ids = cfg.security_group_ids
      }
    },
  )
}

# ***************************************
#  Storage Classes
# ***************************************
resource "kubernetes_storage_class_v1" "this" {
  for_each = var.k8s.enabled ? local.storage_classes : {}

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
  for_each = var.k8s.enabled ? { for key, config in var.k8s.namespaces : key => config if config.enabled } : {}

  metadata {
    name = each.key

    labels = merge(
      local.common_labels,
      { "app.kubernetes.io/component" = "namespace" },
      each.value.labels,
    )

    annotations = merge({
      "terraform.io/module" = "k8s"
    }, each.value.annotations)
  }
}

# ***************************************
#  IAM: role and policy(s) for Kubernetes Service Accounts
# ***************************************
data "aws_iam_policy_document" "service_account" {
  for_each = var.k8s.enabled ? local.service_accounts : {}

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

  # Auto-generated S3 statements from s3_bucket_access.
  # One statement per bucket entry; actions and ARN resolved from var.s3_bucket_arns.
  dynamic "statement" {
    for_each = {
      for bucket_key, bucket_cfg in each.value.s3_bucket_access : bucket_key => {
        arn     = var.s3_bucket_arns[bucket_key]
        actions = bucket_cfg.actions
      }
      if contains(keys(var.s3_bucket_arns), bucket_key)
    }
    iterator = bucket

    content {
      sid       = "AllowS3${replace(title(bucket.key), "-", "")}"
      effect    = "Allow"
      actions   = bucket.value.actions
      resources = [bucket.value.arn, "${bucket.value.arn}/*"]
    }
  }

  # Auto-generated Secrets Manager statement from rds_master_secret_access.
  # Grants GetSecretValue + DescribeSecret on the RDS master user secret.
  dynamic "statement" {
    for_each = each.value.rds_master_secret_access && var.rds_master_secret_arn != null ? [1] : []

    content {
      sid       = "AllowRDSMasterSecretAccess"
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      resources = [var.rds_master_secret_arn]
    }
  }

  # Auto-generated KMS statement from kms_key_access.
  # Grants Sign/Verify/DescribeKey/GetPublicKey on the coprocessor KMS keypair.
  dynamic "statement" {
    for_each = each.value.kms_key_access && var.kms_key_arn != null ? [1] : []

    content {
      sid       = "AllowKMSKeyAccess"
      effect    = "Allow"
      actions   = ["kms:DescribeKey", "kms:GetPublicKey", "kms:Sign", "kms:Verify"]
      resources = [var.kms_key_arn]
    }
  }
}

data "aws_iam_policy_document" "service_account_assume_role" {
  for_each = var.k8s.enabled ? local.service_accounts : {}

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
  for_each = var.k8s.enabled ? local.service_accounts : {}

  name   = coalesce(each.value.iam_role_name_override, "${each.key}-${var.partner_name}-${var.environment}")
  policy = data.aws_iam_policy_document.service_account[each.key].json
}

resource "aws_iam_role" "service_account" {
  for_each = var.k8s.enabled ? local.service_accounts : {}

  name               = coalesce(each.value.iam_role_name_override, "${each.key}-${var.partner_name}-${var.environment}")
  assume_role_policy = data.aws_iam_policy_document.service_account_assume_role[each.key].json
}

resource "aws_iam_role_policy_attachment" "service_account" {
  for_each = var.k8s.enabled ? local.service_accounts : {}

  role       = aws_iam_role.service_account[each.key].name
  policy_arn = aws_iam_policy.service_account[each.key].arn
}

# ***************************************
#  Kubernetes ConfigMaps
# ***************************************
resource "kubernetes_config_map" "db_admin_secret_id" {
  count = var.k8s.enabled ? 1 : 0

  metadata {
    name      = "rds-admin-secret-id"
    namespace = "coproc-admin"

    labels = merge(
      local.common_labels,
      { "app.kubernetes.io/component" = "rds-admin-secret-id" },
    )
  }

  data = {
    RDS_ADMIN_SECRET_ID = var.rds_master_secret_arn
  }

  depends_on = [kubernetes_namespace.this]
}

resource "kubernetes_config_map" "coprocessor_config" {
  for_each = var.k8s.enabled ? toset(["coproc", "eth-blockchain", "gw-blockchain"]) : toset([])

  metadata {
    name      = "coprocessor-config"
    namespace = each.key

    labels = merge(
      local.common_labels,
      { "app.kubernetes.io/component" = "coprocessor-config" },
    )
  }

  data = {
    DATABASE_ENDPOINT = try(
      "${kubernetes_service.external_name["coprocessor-database"].metadata[0].name}.${kubernetes_service.external_name["coprocessor-database"].metadata[0].namespace}.svc.cluster.local",
      null,
    )
    S3_BUCKET_NAME = lookup(var.s3_bucket_names, var.k8s.service_accounts.sns_worker.s3_bucket_key, null)
  }

  depends_on = [kubernetes_namespace.this]
}

# ***************************************
#  Kubernetes Service Accounts
# ***************************************
resource "kubernetes_service_account" "this" {
  for_each = var.k8s.enabled ? local.service_accounts : {}

  metadata {
    name      = each.value.name
    namespace = coalesce(each.value.namespace, local.namespace)

    labels = merge(
      local.common_labels,
      { "app.kubernetes.io/component" = "service-account" },
      each.value.labels,
    )

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
  for_each = var.k8s.enabled ? { for key, config in var.k8s.external_name_services : key => config if config.enabled } : {}

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

# ***************************************
#  SecurityGroupPolicy (EKS Security Groups for Pods)
#
#  Selects pods by label (or SA label) and attaches AWS security groups to the
#  pod's branch ENI. The CRD vpcresources.k8s.aws/v1beta1.SecurityGroupPolicy
#  is installed automatically by EKS via the VPC Resource Controller; pods
#  must schedule on trunk-ENI-capable instance types to receive the SG.
# ***************************************
resource "kubernetes_manifest" "security_group_policy" {
  for_each = local.security_group_policies

  manifest = {
    apiVersion = "vpcresources.k8s.aws/v1beta1"
    kind       = "SecurityGroupPolicy"
    metadata = {
      name      = each.value.name
      namespace = each.value.namespace
      labels = merge(
        local.common_labels,
        { "app.kubernetes.io/component" = "security-group-policy" },
      )
    }
    spec = {
      podSelector = {
        matchLabels = each.value.pod_selector
      }
      securityGroups = {
        groupIds = each.value.security_group_ids
      }
    }
  }

  lifecycle {
    precondition {
      condition     = alltrue([for sg in each.value.security_group_ids : sg != null])
      error_message = "All security_group_ids in a SecurityGroupPolicy must be non-null. For the built-in rds_client policy, this means var.rds_client_security_group_id must be supplied (typically wired from module.rds.rds_client_security_group_id) when k8s.security_group_policies.rds_client.enabled = true."
    }
  }

  depends_on = [kubernetes_namespace.this]
}
