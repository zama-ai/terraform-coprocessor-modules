# ***************************************
# Cross-account IRSA for the tx-sender application
# ***************************************

resource "aws_iam_policy" "tx_sender" {
  count = var.enable_tx_sender_irsa ? 1 : 0

  name = var.tx_sender_role_name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSignVerifyOnTxSenderKey"
        Effect = "Allow"
        Action = [
          "kms:DescribeKey",
          "kms:GetPublicKey",
          "kms:Sign",
          "kms:Verify",
        ]
        Resource = var.tx_sender_kms_key_arn
      },
    ]
  })
}

module "iam_assumable_role_tx_sender" {
  count = var.enable_tx_sender_irsa ? 1 : 0

  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.48.0"

  provider_url                  = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
  create_role                   = true
  role_name                     = var.tx_sender_role_name
  oidc_fully_qualified_subjects = ["system:serviceaccount:${var.tx_sender_namespace}:${var.tx_sender_service_account_name}"]
  role_policy_arns              = [aws_iam_policy.tx_sender[0].arn]
}

resource "kubernetes_service_account" "tx_sender" {
  count = var.enable_tx_sender_irsa && var.tx_sender_create_service_account ? 1 : 0

  metadata {
    name      = var.tx_sender_service_account_name
    namespace = var.tx_sender_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = module.iam_assumable_role_tx_sender[0].iam_role_arn
    }
  }
}
