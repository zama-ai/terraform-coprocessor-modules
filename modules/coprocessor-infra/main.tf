# ***************************************
#  Data sources
# ***************************************
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_subnet" "cluster_subnets" {
  for_each = toset(data.aws_eks_cluster.cluster.vpc_config[0].subnet_ids)
  id       = each.value
}

# ***************************************
#  Local variables
# ***************************************
resource "random_id" "coprocessor_suffix" {
  byte_length = 4
}

locals {
  private_subnet_ids = [
    for subnet_id, subnet in data.aws_subnet.cluster_subnets : subnet_id
    if subnet.map_public_ip_on_launch == false
  ]
  private_subnet_cidr_blocks = [
    for subnet_id, subnet in data.aws_subnet.cluster_subnets : subnet.cidr_block
    if subnet.map_public_ip_on_launch == false
  ]
  coprocessor_bucket_name = "${var.bucket_prefix}-${random_id.coprocessor_suffix.hex}"
}

# Create Kubernetes namespace (optional)
resource "kubernetes_namespace" "coprocessor_namespace" {
  count = var.create_coprocessor_namespace ? 1 : 0

  metadata {
    name = var.k8s_coprocessor_namespace

    labels = merge({
      "app.kubernetes.io/name"       = "coprocessor"
      "app.kubernetes.io/component"  = "storage"
      "app.kubernetes.io/part-of"    = "zama-protocol"
      "app.kubernetes.io/managed-by" = "terraform"
    }, var.namespace_labels)

    annotations = merge({
      "terraform.io/module" = "coprocessor"
    }, var.namespace_annotations)
  }
}

# ***************************************
#  S3 Buckets for Vault Public Storage
# ***************************************
resource "aws_s3_bucket" "coprocessor_bucket" {
  bucket        = local.coprocessor_bucket_name
  force_destroy = true
  tags = merge(var.tags, {
    "Name"    = local.coprocessor_bucket_name
    "Type"    = "coprocessor-bucket"
    "Purpose" = "coprocessor-storage"
  })
}

resource "aws_s3_bucket_ownership_controls" "coprocessor_bucket" {
  bucket = aws_s3_bucket.coprocessor_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "coprocessor_bucket" {
  bucket = aws_s3_bucket.coprocessor_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "coprocessor_bucket" {
  bucket = aws_s3_bucket.coprocessor_bucket.id

  block_public_policy     = false
  restrict_public_buckets = false
  block_public_acls       = false
  ignore_public_acls      = false
}

resource "aws_s3_bucket_cors_configuration" "coprocessor_bucket_cors" {
  bucket = aws_s3_bucket.coprocessor_bucket.id

  cors_rule {
    allowed_headers = ["Authorization"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["Access-Control-Allow-Origin"]
  }
}

resource "aws_s3_bucket_policy" "coprocessor_bucket_policy" {
  bucket = aws_s3_bucket.coprocessor_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicRead"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::${aws_s3_bucket.coprocessor_bucket.id}/*"
      },
      {
        Sid       = "ZamaList"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:ListBucket"
        Resource  = "arn:aws:s3:::${aws_s3_bucket.coprocessor_bucket.id}"
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.coprocessor_bucket]
}

# ***************************************
#  IAM Policy for coprocessor Party
# ***************************************
resource "aws_iam_policy" "coprocessor_aws" {
  name = "coprocessor-${var.cluster_name}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowObjectActions"
        Effect = "Allow"
        Action = "s3:*Object"
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.coprocessor_bucket.id}/*",
        ]
      },
      {
        Sid    = "AllowListBucket"
        Effect = "Allow"
        Action = "s3:ListBucket"
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.coprocessor_bucket.id}",
        ]
      }
    ]
  })
}


module "iam_assumable_role_coprocessor" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "5.48.0"
  provider_url                  = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
  create_role                   = true
  role_name                     = var.coprocessor_role_name != "" ? var.coprocessor_role_name : aws_iam_policy.coprocessor_aws.name
  oidc_fully_qualified_subjects = ["system:serviceaccount:${var.k8s_coprocessor_namespace}:${var.k8s_coprocessor_service_account_name}"]
  role_policy_arns              = [aws_iam_policy.coprocessor_aws.arn]
  depends_on                    = [aws_s3_bucket.coprocessor_bucket, kubernetes_namespace.coprocessor_namespace]
}

resource "kubernetes_service_account" "coprocessor_service_account" {
  count = var.create_service_account ? 1 : 0

  metadata {
    name      = var.k8s_coprocessor_service_account_name
    namespace = var.k8s_coprocessor_namespace

    labels = merge({
      "app.kubernetes.io/name"       = "coprocessor"
      "app.kubernetes.io/component"  = "service-account"
      "app.kubernetes.io/part-of"    = "zama-protocol"
      "app.kubernetes.io/managed-by" = "terraform"
    }, var.service_account_labels)

    annotations = merge({
      "terraform.io/module"        = "coprocessor"
      "eks.amazonaws.com/role-arn" = module.iam_assumable_role_coprocessor.iam_role_arn
    }, var.service_account_annotations)
  }
  depends_on = [kubernetes_namespace.coprocessor_namespace, module.iam_assumable_role_coprocessor]
}

# ***************************************
#  RDS instance
# ***************************************
locals {
  external_name = var.rds_db_name != null ? substr(lower(replace("${var.rds_prefix}-${var.network_environment}-${var.rds_db_name}", "/[^a-z0-9-]/", "-")), 0, 63) : "${var.rds_prefix}-${var.network_environment}-rds"
  db_identifier = var.rds_identifier_override != null ? var.rds_identifier_override : local.external_name
}

module "rds_instance" {
  count = var.enable_rds ? 1 : 0

  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.10"

  identifier = local.db_identifier

  engine         = var.rds_engine
  engine_version = var.rds_engine_version
  family         = "postgres${floor(var.rds_engine_version)}"

  instance_class        = var.rds_instance_class
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  multi_az              = var.rds_multi_az
  parameters            = var.rds_parameters

  db_name  = var.rds_db_name
  username = var.rds_username
  port     = var.rds_port

  password                                               = var.rds_db_password
  manage_master_user_password                            = var.rds_db_password != null ? false : true
  manage_master_user_password_rotation                   = var.rds_enable_master_password_rotation
  master_user_password_rotation_automatically_after_days = var.rds_master_password_rotation_days

  iam_database_authentication_enabled = false

  maintenance_window      = var.rds_maintenance_window
  backup_retention_period = var.rds_backup_retention_period

  monitoring_interval    = var.rds_monitoring_interval
  create_monitoring_role = var.rds_create_monitoring_role
  monitoring_role_name   = var.rds_monitoring_role_name
  monitoring_role_arn    = var.rds_monitoring_role_arn

  create_db_subnet_group = true
  subnet_ids             = local.private_subnet_ids
  vpc_security_group_ids = [module.rds_security_group[0].security_group_id]

  deletion_protection = var.rds_deletion_protection
  tags                = var.tags
}

module "rds_security_group" {
  count = var.enable_rds ? 1 : 0

  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.3.0"

  name        = var.rds_db_name != null ? var.rds_db_name : "rds-sg"
  description = "Security group for ${var.rds_db_name != null ? var.rds_db_name : "RDS"} RDS Postgres opened port within VPC"
  vpc_id      = var.rds_vpc_id == null ? data.aws_eks_cluster.cluster.vpc_config[0].vpc_id : var.rds_vpc_id
  ingress_with_cidr_blocks = [
    {
      from_port   = var.rds_port
      to_port     = var.rds_port
      protocol    = "tcp"
      cidr_blocks = join(",", concat(var.rds_allowed_cidr_blocks, local.private_subnet_cidr_blocks))
    }
  ]
  tags = var.tags
}

resource "kubernetes_service" "externalname" {
  count = var.enable_rds && var.rds_create_externalname_service ? 1 : 0

  metadata {
    name        = var.rds_externalname_service_name
    namespace   = var.rds_externalname_service_namespace
    annotations = var.rds_externalname_service_annotations
  }
  spec {
    type          = "ExternalName"
    external_name = split(":", module.rds_instance[0].db_instance_endpoint)[0]
  }
}
