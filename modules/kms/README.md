<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_kms_alias.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_external_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_external_key) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (e.g. testnet, mainnet), used in the KMS alias name. | `string` | n/a | yes |
| <a name="input_kms"></a> [kms](#input\_kms) | KMS coprocessor keypair configuration.<br/><br/>Creates an asymmetric AWS KMS key with EXTERNAL origin (key material to be<br/>imported out of band — typically an Ethereum secp256k1 private key) plus<br/>an alias of the form `alias/<partner_name>-<environment>-coprocessor-keypair`.<br/><br/>Cross-account: the module uses the default `aws` provider. To create the<br/>key in a different account from the rest of the infrastructure, pass an<br/>aliased provider via `providers = { aws = aws.kms_account }` when calling<br/>the module. consumer\_role\_arns may live in any account. Alternativley,<br/>simply invoke the submodule in its own terraform deployment isloated from<br/>the other submodules. | <pre>object({<br/>    enabled = optional(bool, false)<br/><br/>    # IAM principal ARNs allowed to Sign/Verify/DescribeKey/GetPublicKey on the key.<br/>    # May reference roles in a different account from the key (cross-account use).<br/>    consumer_role_arns = optional(list(string), [])<br/><br/>    # KMS deletion window in days (7-30).<br/>    deletion_window_in_days = optional(number, 30)<br/><br/>    # Tags applied to the key.<br/>    tags = optional(map(string), {})<br/>  })</pre> | <pre>{<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_partner_name"></a> [partner\_name](#input\_partner\_name) | Partner identifier, used in the KMS alias name. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alias_arn"></a> [alias\_arn](#output\_alias\_arn) | KMS alias ARN (null when kms.enabled = false). |
| <a name="output_alias_name"></a> [alias\_name](#output\_alias\_name) | KMS alias name (null when kms.enabled = false). |
| <a name="output_key_arn"></a> [key\_arn](#output\_key\_arn) | KMS key ARN of the coprocessor keypair (null when kms.enabled = false). |
| <a name="output_key_id"></a> [key\_id](#output\_key\_id) | KMS key ID of the coprocessor keypair (null when kms.enabled = false). |
<!-- END_TF_DOCS -->
