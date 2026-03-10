output "bucket_names" {
  description = "Map of logical bucket key to bucket name."
  value       = { for key, value in aws_s3_bucket.this : key => value.id }
}

output "bucket_arns" {
  description = "Map of logical bucket key to bucket ARN."
  value       = { for key, value in aws_s3_bucket.this : key => value.arn }
}
