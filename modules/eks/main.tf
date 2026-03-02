data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  # VPC CNI config must be JSON
  vpc_cni_configuration_values = jsonencode(var.addons.vpc_cni_config)

  eks_default_addons_with_config = merge(
    var.addons.default,
    {
      vpc-cni = merge(try(var.addons.default["vpc-cni"], {}), {
        configuration_values = local.vpc_cni_configuration_values
      })
    }
  )

  # Effective addons = defaults (with VPC CNI config) merged with extra overrides
  eks_addons = merge(local.eks_default_addons_with_config, var.addons.extra)

  # Optionally add a dedicated controller node group for Karpenter
  karpenter_controller_nodegroup = var.karpenter.controller_nodegroup_enabled ? {
    karpenter-controller = merge(
      var.karpenter.controller_nodegroup_config,
      {
        labels = merge(
          try(var.karpenter.controller_nodegroup_config.labels, {}),
          {
            "karpenter.sh/controller" = "true"
          }
        )
      }
    )
  } : {}

  # Select subnets per node group: default to private subnets, optionally route specific node groups
  # to the provided additional subnets.
  eks_managed_node_groups_with_subnet_ids = {
    for node_group_name, node_group in var.node_groups.managed :
    node_group_name => merge(
      node_group,
      contains(var.network.node_groups_using_additional_subnets, node_group_name)
      ? { subnet_ids = var.network.additional_subnet_ids }
      : { subnet_ids = null }
    )
  }

  # Merge node groups:
  # - base groups (with subnet selection)
  # - optional karpenter controller nodegroup
  # Then apply defaults + inject default IAM policies.
  eks_managed_node_groups_effective = {
    for k, v in merge(local.eks_managed_node_groups_with_subnet_ids, local.karpenter_controller_nodegroup) : k => merge(
      var.node_groups.defaults,
      v,
      {
        iam_role_additional_policies = merge(
          lookup(v, "iam_role_additional_policies", {}),
          var.node_groups.default_iam_role_additional_policies,
        )
      }
    )
  }

  # Node security group tags: add karpenter discovery tag when karpenter enabled
  node_security_group_tags = merge(
    (var.karpenter.enabled ? { "karpenter.sh/discovery" = var.name } : {}),
    { "kubernetes.io/cluster/${var.name}" = null }
  )

  # Friendly names (avoid very long names where AWS has limits)
  karpenter_queue_name = var.karpenter.queue_name != null ? var.karpenter.queue_name : "${var.name}-Karpenter"
  karpenter_rule_name_prefix = var.karpenter.rule_name_prefix != null ? var.karpenter.rule_name_prefix : substr(var.name, 0, min(20, length(var.name)))

  cluster_encryption_policy_name          = var.karpenter.enabled ? "${var.name}-ClusterEncryptionPolicy" : null
  instance_profile_management_policy_name = var.karpenter.enabled ? "${var.name}-KarpenterInstanceProfileManagement" : null
}


module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name                         = var.name
  kubernetes_version           = var.cluster.kubernetes_version

  endpoint_public_access       = var.cluster.endpoint_public_access
  endpoint_private_access      = var.cluster.endpoint_private_access
  endpoint_public_access_cidrs = var.cluster.endpoint_public_access_cidrs

  vpc_id     = var.network.vpc_id
  subnet_ids = var.network.private_subnet_ids

  enable_irsa                              = var.cluster.enable_irsa
  enable_cluster_creator_admin_permissions = var.cluster.enable_cluster_creator_admin_permissions

  addons = local.eks_addons

  eks_managed_node_groups = local.eks_managed_node_groups_effective

  node_security_group_tags = local.node_security_group_tags

  tags = var.tags
}

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

  # Attach additional IAM policies to the Karpenter node IAM role (merged with node group defaults)
  node_iam_role_additional_policies = merge(
    var.node_groups.default_iam_role_additional_policies,
    var.karpenter.node_iam_role_additional_policies
  )

  create_pod_identity_association = true
  create_access_entry             = true

  queue_name       = local.karpenter_queue_name
  rule_name_prefix = local.karpenter_rule_name_prefix

  tags = merge(var.tags, {
    Environment = module.eks.cluster_name
    ManagedBy   = "terraform"
  })
}

# Access entries for cluster admins (recommended over the legacy aws-auth config)
resource "aws_eks_access_entry" "admin_roles" {
  for_each      = toset(var.access.admin_role_arns)
  cluster_name  = module.eks.cluster_name
  principal_arn = each.value
  type          = "STANDARD"
  tags          = var.tags
}

resource "aws_eks_access_policy_association" "admin_roles" {
  for_each      = toset(var.access.admin_role_arns)
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = each.value

  access_scope {
    type = "cluster"
  }
}

# Karpenter: additional IAM policy for encryption (EBS, etc.)
resource "aws_iam_policy" "karpenter_controller_encryption" {
  count       = var.karpenter.enabled ? 1 : 0
  name        = local.cluster_encryption_policy_name
  description = "IAM policy for Karpenter controller encryption"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
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
      }
    ]
  })

  tags = var.tags
}

# Karpenter: instance profile management policy (needed in some orgs where instance profiles are tightly controlled)
resource "aws_iam_policy" "karpenter_controller_instance_profile" {
  count       = var.karpenter.enabled ? 1 : 0
  name        = local.instance_profile_management_policy_name
  description = "IAM policy for Karpenter controller to manage instance profiles"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:ListInstanceProfiles",
          "iam:GetInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile"
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/karpenter/*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_service_linked_role" "spot_role" {
  count            = var.karpenter.enabled ? 1 : 0
  aws_service_name = "spot.amazonaws.com"
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_encryption" {
  count      = var.karpenter.enabled ? 1 : 0
  role       = module.karpenter[0].iam_role_name
  policy_arn = aws_iam_policy.karpenter_controller_encryption[0].arn
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_instance_profile" {
  count      = var.karpenter.enabled ? 1 : 0
  role       = module.karpenter[0].iam_role_name
  policy_arn = aws_iam_policy.karpenter_controller_instance_profile[0].arn
}
