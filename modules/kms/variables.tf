variable "partner_name" {
  description = "Partner identifier, used in the KMS alias name."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. testnet, mainnet), used in the KMS alias name."
  type        = string
}

variable "kms" {
  description = <<-EOT
    KMS coprocessor keypair configuration.

    Creates an asymmetric AWS KMS key (key spec ECC_SECG_P256K1, key usage
    SIGN_VERIFY) with KMS-generated key material — the private key is
    generated inside the HSM and never leaves it. The corresponding Ethereum
    address is derived client-side from the public key returned by
    `kms:GetPublicKey` (uncompressed sec1 form, keccak256 of the last 64
    bytes, take last 20). An alias of the form
    `alias/<partner_name>-<environment>-coprocessor-keypair` is created
    alongside the key.

    Cross-account: the module uses the default `aws` provider. To create the
    key in a different account from the rest of the infrastructure, pass an
    aliased provider via `providers = { aws = aws.kms_account }` when calling
    the module. consumer_role_arns may live in any account. Alternatively,
    simply invoke the submodule in its own terraform deployment isolated from
    the other submodules.
  EOT

  type = object({
    enabled = optional(bool, false)

    # IAM principal ARNs allowed to Sign/Verify/DescribeKey/GetPublicKey on the key.
    # May reference roles in a different account from the key (cross-account use).
    consumer_role_arns = optional(list(string), [])

    # KMS deletion window in days (7-30).
    deletion_window_in_days = optional(number, 30)

    # Tags applied to the key.
    tags = optional(map(string), {})
  })

  default = { enabled = false }
}
