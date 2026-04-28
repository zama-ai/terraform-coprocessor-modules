output "key_id" {
  description = "KMS key ID of the coprocessor keypair (null when kms.enabled = false)."
  value       = one(aws_kms_external_key.this[*].id)
}

output "key_arn" {
  description = "KMS key ARN of the coprocessor keypair (null when kms.enabled = false)."
  value       = one(aws_kms_external_key.this[*].arn)
}

output "alias_name" {
  description = "KMS alias name (null when kms.enabled = false)."
  value       = one(aws_kms_alias.this[*].name)
}

output "alias_arn" {
  description = "KMS alias ARN (null when kms.enabled = false)."
  value       = one(aws_kms_alias.this[*].arn)
}
