data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  # ----------------------------------------
  #  Cluster name
  # ----------------------------------------
  cluster_name = coalesce(var.cluster.name_override, "${var.name}-${var.environment}")

  # ----------------------------------------
  #  Addons
  # ----------------------------------------
  vpc_cni_configuration_values = jsonencode(var.addons.vpc_cni_config)

  merged_addons = merge(
    var.addons.defaults,
    {
      vpc-cni = merge(
        lookup(var.addons.defaults, "vpc-cni", { most_recent = true, before_compute = true }),
        { configuration_values = local.vpc_cni_configuration_values }
      )
    },
    var.addons.extra
  )

  # ----------------------------------------
  #  Node Groups
  # ----------------------------------------
  node_groups_with_subnets = {
    for name, cfg in var.node_groups.groups :
    name => merge(cfg, {
      subnet_ids = cfg.use_additional_subnets ? var.additional_subnet_ids : null
    })
  }

  karpenter_controller_nodegroup = var.karpenter.enabled && var.karpenter.controller_nodegroup.enabled ? {
    karpenter-controller = merge(
      var.karpenter.controller_nodegroup,
      {
        labels = merge(
          try(var.karpenter.controller_nodegroup.labels, {}),
          { "karpenter.sh/controller" = "true" }
        )
      }
    )
  } : {}

  all_node_groups = merge(local.node_groups_with_subnets, local.karpenter_controller_nodegroup)

  # ----------------------------------------
  #  Karpenter naming
  # ----------------------------------------
  karpenter_queue_name       = var.karpenter.queue_name != null ? var.karpenter.queue_name : "${local.cluster_name}-Karpenter"
  karpenter_rule_name_prefix = var.karpenter.rule_name_prefix != null ? var.karpenter.rule_name_prefix : substr(local.cluster_name, 0, 20)

  # ----------------------------------------
  #  IAM policy names
  # ----------------------------------------
  cluster_encryption_policy_name          = var.karpenter.enabled ? "${local.cluster_name}-ClusterEncryptionPolicy" : null
  instance_profile_management_policy_name = var.karpenter.enabled ? "${local.cluster_name}-KarpenterInstanceProfileManagement" : null
}

# ***************************************
#  EKS Cluster
# ***************************************
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0.6"

  name               = local.cluster_name
  kubernetes_version = var.cluster.version
  vpc_id             = var.vpc_id
  subnet_ids         = var.private_subnet_ids

  endpoint_public_access       = var.cluster.endpoint_public_access
  endpoint_private_access      = var.cluster.endpoint_private_access
  endpoint_public_access_cidrs = var.cluster.endpoint_public_access_cidrs

  enable_cluster_creator_admin_permissions = var.cluster.enable_creator_admin_permissions
  enable_irsa                              = var.cluster.enable_irsa

  addons = local.merged_addons

  eks_managed_node_groups = {
    for k, v in local.all_node_groups : k => merge(
      var.node_groups.defaults,
      v,
      {
        iam_role_additional_policies = merge(
          lookup(v, "iam_role_additional_policies", {}),
          var.node_groups.default_iam_policies
        )
      }
    )
  }

  node_security_group_tags = merge(
    var.karpenter.enabled ? { "karpenter.sh/discovery" = local.cluster_name } : {},
    { "kubernetes.io/cluster/${local.cluster_name}" = null }
  )
}

# ***************************************
#  Cluster Access — Admin Roles
# ***************************************
resource "aws_eks_access_entry" "admin_roles" {
  for_each      = toset(var.cluster.admin_role_arns)
  cluster_name  = module.eks.cluster_name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin_roles" {
  for_each      = toset(var.cluster.admin_role_arns)
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = each.value

  access_scope {
    type = "cluster"
  }
}

# ***************************************
#  Karpenter
# ***************************************
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 21.0"
  count   = var.karpenter.enabled ? 1 : 0

  cluster_name                  = module.eks.cluster_name
  iam_policy_use_name_prefix    = false
  iam_role_use_name_prefix      = false
  node_iam_role_use_name_prefix = false
  iam_policy_name               = "${module.eks.cluster_name}-KarpenterController"
  iam_role_name                 = "${module.eks.cluster_name}-KarpenterController"
  node_iam_role_name            = "${module.eks.cluster_name}-Karpenter"
  namespace                     = var.karpenter.namespace
  service_account               = var.karpenter.service_account
  queue_name                    = local.karpenter_queue_name
  rule_name_prefix              = local.karpenter_rule_name_prefix

  node_iam_role_additional_policies = merge(
    var.node_groups.default_iam_policies,
    var.karpenter.node_iam_role_additional_policies
  )

  create_pod_identity_association = true
  create_access_entry             = true

  tags = {
    Environment = module.eks.cluster_name
  }
}

# ***************************************
#  Karpenter — IAM Policies
# ***************************************
resource "aws_iam_policy" "karpenter_encryption" {
  count       = var.karpenter.enabled ? 1 : 0
  name        = local.cluster_encryption_policy_name
  description = "Allows Karpenter controller to use KMS for EBS encryption."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "kms:CreateGrant",
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:GenerateDataKeyWithoutPlaintext"
      ]
      Resource = "*"
      Condition = {
        StringEquals = {
          "kms:ViaService" = "ec2.${data.aws_region.current.name}.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_policy" "karpenter_instance_profile" {
  count       = var.karpenter.enabled ? 1 : 0
  name        = local.instance_profile_management_policy_name
  description = "Allows Karpenter controller to manage EC2 instance profiles."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "iam:ListInstanceProfiles",
        "iam:GetInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile"
      ]
      Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/karpenter/*"
    }]
  })
}

resource "aws_iam_service_linked_role" "spot" {
  count            = var.karpenter.enabled ? 1 : 0
  aws_service_name = "spot.amazonaws.com"
}

resource "aws_iam_role_policy_attachment" "karpenter_encryption" {
  count      = var.karpenter.enabled ? 1 : 0
  role       = module.karpenter[0].iam_role_name
  policy_arn = aws_iam_policy.karpenter_encryption[0].arn
}

resource "aws_iam_role_policy_attachment" "karpenter_instance_profile" {
  count      = var.karpenter.enabled ? 1 : 0
  role       = module.karpenter[0].iam_role_name
  policy_arn = aws_iam_policy.karpenter_instance_profile[0].arn
}
