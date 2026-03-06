# ***************************************
#  Stable random suffix per bucket
# ***************************************
resource "random_id" "suffix" {
  for_each    = var.buckets

  byte_length = 4
  keepers = {
    partner_name = var.partner_name
    environment  = var.environment
    bucket_key   = each.key
  }
}

# ***************************************
#  Local variables
# ***************************************
locals {
  bucket_names = {
    for key in keys(var.buckets) :
    key => coalesce(var.buckets[key].name_override, "${var.partner_name}-${var.environment}-${key}-${random_id.suffix[key].hex}")
  }
}

# ***************************************
#  Buckets
# ***************************************
resource "aws_s3_bucket" "this" {
  for_each      = var.buckets

  bucket        = local.bucket_names[each.key]
  force_destroy = each.value.force_destroy

  tags = {
    Name        = local.bucket_names[each.key]
    Type        = "${each.key}-bucket"
    Purpose     = each.value.purpose
    Partner     = var.partner_name
    Environment = var.environment
  }
}

resource "aws_s3_bucket_ownership_controls" "this" {
  for_each = var.buckets
  bucket   = aws_s3_bucket.this[each.key].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = var.buckets
  bucket   = aws_s3_bucket.this[each.key].id

  versioning_configuration {
    status = each.value.versioning ? "Enabled" : "Suspended"
  }
}

# ***************************************
#  Bucket Access
# ***************************************
resource "aws_s3_bucket_public_access_block" "this" {
  for_each = var.buckets
  bucket   = aws_s3_bucket.this[each.key].id

  block_public_acls       = !each.value.public_access.enabled
  ignore_public_acls      = !each.value.public_access.enabled
  block_public_policy     = !each.value.public_access.enabled
  restrict_public_buckets = !each.value.public_access.enabled
}

data "aws_iam_policy_document" "this" {
  for_each = {
    for key, value in var.buckets : key => value
    if length(value.policy_statements) > 0
  }

  dynamic "statement" {
    for_each = each.value.policy_statements

    content {
      sid     = statement.value.sid
      effect  = statement.value.effect
      actions = statement.value.actions

      resources = [
        for resource in statement.value.resources : (
          resource == "bucket"  ? aws_s3_bucket.this[each.key].arn :
          resource == "objects" ? "${aws_s3_bucket.this[each.key].arn}/*" :
          resource
        )
      ]

      dynamic "principals" {
        for_each = contains(keys(statement.value.principals), "*") ? [1] : []
        content {
          type        = "*"
          identifiers = ["*"]
        }
      }

      dynamic "principals" {
        for_each = { for k, v in statement.value.principals : k => v if k != "*" }
        content {
          type        = principals.key
          identifiers = principals.value
        }
      }

      dynamic "condition" {
        for_each = statement.value.conditions
        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  for_each = data.aws_iam_policy_document.this

  bucket = aws_s3_bucket.this[each.key].id
  policy = each.value.json

  depends_on = [aws_s3_bucket_public_access_block.this]
}

# ***************************************
#  CORS
# ***************************************
resource "aws_s3_bucket_cors_configuration" "this" {
  for_each = {
    for key, value in var.buckets : key => value
    if value.cors.enabled
  }

  bucket = aws_s3_bucket.this[each.key].id

  cors_rule {
    allowed_origins = each.value.cors.allowed_origins
    allowed_methods = each.value.cors.allowed_methods
    allowed_headers = each.value.cors.allowed_headers
    expose_headers  = each.value.cors.expose_headers
  }
}