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

    Creates an asymmetric AWS KMS key with EXTERNAL origin (key material to be
    imported out of band — typically an Ethereum secp256k1 private key) plus
    an alias of the form `alias/<partner_name>-<environment>-coprocessor-keypair`.

    Cross-account: the module uses the default `aws` provider. To create the
    key in a different account from the rest of the infrastructure, pass an
    aliased provider via `providers = { aws = aws.kms_account }` when calling
    the module. consumer_role_arns may live in any account. Alternativley,
    simply invoke the submodule in its own terraform deployment isloated from
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
