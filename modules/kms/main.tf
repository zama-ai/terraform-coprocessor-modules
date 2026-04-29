# ***************************************
#  Data sources
# ***************************************
# Resolves to the account the configured AWS provider points at — this is the
# account the key is created in, which may differ from the account hosting
# the consuming roles when used cross-account.
data "aws_caller_identity" "current" {}

# ***************************************
#  Coprocessor Ethereum keypair (imported key material)
# ***************************************
resource "aws_kms_external_key" "this" {
  count = var.kms.enabled ? 1 : 0

  description             = "Coprocessor Ethereum keypair (imported secp256k1 private key)"
  key_usage               = "SIGN_VERIFY"
  key_spec                = "ECC_SECG_P256K1"
  deletion_window_in_days = var.kms.deletion_window_in_days
  tags                    = var.kms.tags

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      length(var.kms.consumer_role_arns) > 0 ? [
        {
          Sid       = "AllowConsumerSignVerify"
          Effect    = "Allow"
          Principal = { AWS = var.kms.consumer_role_arns }
          Action    = ["kms:DescribeKey", "kms:GetPublicKey", "kms:Sign", "kms:Verify"]
          Resource  = "*"
        }
      ] : [],
      [
        {
          Sid       = "AllowRootAdmin"
          Effect    = "Allow"
          Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
          Action = [
            "kms:Create*",
            "kms:Describe*",
            "kms:Enable*",
            "kms:List*",
            "kms:Put*",
            "kms:Update*",
            "kms:Revoke*",
            "kms:Disable*",
            "kms:Get*",
            "kms:Delete*",
            "kms:TagResource",
            "kms:UntagResource",
            "kms:ScheduleKeyDeletion",
            "kms:CancelKeyDeletion",
            "kms:ImportKeyMaterial",
            "kms:DeleteImportedKeyMaterial"
          ]
          Resource = "*"
        }
      ],
    )
  })
}

# ***************************************
#  Alias for the coprocessor keypair
# ***************************************
resource "aws_kms_alias" "this" {
  count = var.kms.enabled ? 1 : 0

  name          = "alias/${var.partner_name}-${var.environment}-coprocessor-keypair"
  target_key_id = aws_kms_external_key.this[0].id
}
