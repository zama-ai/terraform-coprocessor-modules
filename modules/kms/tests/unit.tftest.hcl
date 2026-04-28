mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/test"
      user_id    = "AIDAEXAMPLE"
    }
  }
}

variables {
  partner_name = "acme"
  environment  = "testnet"
}

run "disabled_creates_no_resources" {
  command = plan

  variables {
    kms = { enabled = false }
  }

  assert {
    condition     = length(aws_kms_external_key.this) == 0
    error_message = "No KMS key must be created when kms.enabled = false."
  }

  assert {
    condition     = length(aws_kms_alias.this) == 0
    error_message = "No KMS alias must be created when kms.enabled = false."
  }
}

run "enabled_creates_key_with_alias_and_consumer_policy" {
  command = plan

  variables {
    kms = {
      enabled            = true
      consumer_role_arns = ["arn:aws:iam::555555555555:role/coprocessor-consumer"]
    }
  }

  assert {
    condition     = aws_kms_external_key.this[0].key_spec == "ECC_SECG_P256K1"
    error_message = "Key spec must be ECC_SECG_P256K1 (Ethereum secp256k1)."
  }

  assert {
    condition     = aws_kms_external_key.this[0].key_usage == "SIGN_VERIFY"
    error_message = "Key usage must be SIGN_VERIFY."
  }

  assert {
    condition     = aws_kms_alias.this[0].name == "alias/acme-testnet-coprocessor-keypair"
    error_message = "Alias must be alias/<partner>-<environment>-coprocessor-keypair."
  }

  assert {
    condition     = strcontains(aws_kms_external_key.this[0].policy, "arn:aws:iam::555555555555:role/coprocessor-consumer")
    error_message = "Key policy must reference the supplied consumer_role_arns."
  }
}
