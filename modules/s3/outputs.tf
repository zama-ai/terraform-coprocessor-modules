output "bucket_names" {
  description = "Map of logical bucket key to bucket name."
  value       = { for key, value in aws_s3_bucket.this : key => value.id }
}

output "bucket_arns" {
  description = "Map of logical bucket key to bucket ARN."
  value       = { for key, value in aws_s3_bucket.this : key => value.arn }
}

output "cloudfront_domain_names" {
  description = "Map of logical bucket key to CloudFront distribution domain name. Empty for buckets without CloudFront enabled."
  value       = { for key, value in aws_cloudfront_distribution.this : key => value.domain_name }
}

output "cloudfront_distribution_ids" {
  description = "Map of logical bucket key to CloudFront distribution ID. Empty for buckets without CloudFront enabled."
  value       = { for key, value in aws_cloudfront_distribution.this : key => value.id }
}
