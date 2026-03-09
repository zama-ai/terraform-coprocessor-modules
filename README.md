## Pre-commit

This repo uses [pre-commit](https://pre-commit.com/) to enforce consistency on every commit.

**Setup:**

```bash
pip install pre-commit
pre-commit install
```

**Hooks that run automatically:**

| Hook | What it does |
|------|-------------|
| `terraform_fmt` | Formats all `.tf` files |
| `terraform_validate` | Validates module configuration |
| `terraform_tflint` | Lints for common mistakes and best practices |
| `terraform_docs` | Regenerates the `<!-- BEGIN_TF_DOCS -->` sections in all `README.md` files |

To run all hooks manually: `pre-commit run --all-files`

---

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eks"></a> [eks](#module\_eks) | ./modules/eks | n/a |
| <a name="module_networking"></a> [networking](#module\_networking) | ./modules/networking | n/a |
| <a name="module_rds"></a> [rds](#module\_rds) | ./modules/rds | n/a |
| <a name="module_s3"></a> [s3](#module\_s3) | ./modules/s3 | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region where resources will be deployed. | `string` | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | Tags to apply to all resources. | `map(string)` | `{}` | no |
| <a name="input_eks"></a> [eks](#input\_eks) | EKS cluster configuration. Set enabled = false to skip all EKS resources. | <pre>object({<br/>    enabled = optional(bool, true)<br/><br/>    cluster = optional(object({<br/>      version                          = optional(string, "1.32")<br/>      name_override                    = optional(string, null)<br/>      endpoint_public_access           = optional(bool, false)<br/>      endpoint_private_access          = optional(bool, true)<br/>      endpoint_public_access_cidrs     = optional(list(string), [])<br/>      enable_irsa                      = optional(bool, true)<br/>      enable_creator_admin_permissions = optional(bool, true)<br/>      admin_role_arns                  = optional(list(string), [])<br/>    }), {})<br/><br/>    addons = optional(object({<br/>      defaults = optional(map(any), {<br/>        aws-ebs-csi-driver     = { most_recent = true }<br/>        coredns                = { most_recent = true }<br/>        vpc-cni                = { most_recent = true, before_compute = true }<br/>        kube-proxy             = { most_recent = true }<br/>        eks-pod-identity-agent = { most_recent = true }<br/>      })<br/>      extra = optional(map(any), {})<br/>      vpc_cni_config = optional(object({<br/>        init = optional(object({<br/>          env = optional(object({<br/>            DISABLE_TCP_EARLY_DEMUX = optional(string, "true")<br/>          }), {})<br/>        }), {})<br/>        env = optional(object({<br/>          ENABLE_POD_ENI                    = optional(string, "true")<br/>          POD_SECURITY_GROUP_ENFORCING_MODE = optional(string, "standard")<br/>          ENABLE_PREFIX_DELEGATION          = optional(string, "true")<br/>          WARM_PREFIX_TARGET                = optional(string, "1")<br/>        }), {})<br/>      }), {})<br/>    }), {})<br/><br/>    node_groups = optional(object({<br/>      defaults = optional(map(any), {})<br/>      default_iam_policies = optional(map(string), {<br/>        AmazonEBSCSIDriverPolicy           = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"<br/>        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"<br/>        AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"<br/>      })<br/>      groups = optional(map(object({<br/>        capacity_type              = optional(string, "ON_DEMAND")<br/>        min_size                   = optional(number, 1)<br/>        max_size                   = optional(number, 3)<br/>        desired_size               = optional(number, 1)<br/>        instance_types             = optional(list(string), ["t3.medium"])<br/>        ami_type                   = optional(string, "AL2023_x86_64_STANDARD")<br/>        use_custom_launch_template = optional(bool, false)<br/>        disk_size                  = optional(number, 30)<br/>        disk_type                  = optional(string, "gp3")<br/>        labels                     = optional(map(string), {})<br/>        tags                       = optional(map(string), {})<br/>        use_additional_subnets     = optional(bool, false)<br/>        update_config = optional(object({<br/>          max_unavailable            = optional(number)<br/>          max_unavailable_percentage = optional(number)<br/>        }), { max_unavailable = 1 })<br/>        taints = optional(map(object({<br/>          key    = string<br/>          value  = optional(string)<br/>          effect = string<br/>        })), {})<br/>        iam_role_additional_policies = optional(map(string), {})<br/>        metadata_options = optional(map(string), {<br/>          http_endpoint               = "enabled"<br/>          http_put_response_hop_limit = "2"<br/>          http_tokens                 = "required"<br/>        })<br/>      })), {})<br/>    }), {})<br/><br/>    karpenter = optional(object({<br/>      enabled          = optional(bool, false)<br/>      namespace        = optional(string, "karpenter")<br/>      service_account  = optional(string, "karpenter")<br/>      queue_name       = optional(string, null)<br/>      rule_name_prefix = optional(string, null)<br/>      node_iam_role_additional_policies = optional(map(string), {<br/>        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"<br/>      })<br/>      controller_nodegroup = optional(object({<br/>        enabled        = optional(bool, false)<br/>        capacity_type  = optional(string, "ON_DEMAND")<br/>        min_size       = optional(number, 1)<br/>        max_size       = optional(number, 2)<br/>        desired_size   = optional(number, 1)<br/>        instance_types = optional(list(string), ["t3.small"])<br/>        ami_type       = optional(string, "AL2023_x86_64_STANDARD")<br/>        disk_size      = optional(number, 50)<br/>        disk_type      = optional(string, "gp3")<br/>        labels         = optional(map(string), { "karpenter.sh/controller" = "true" })<br/>        taints = optional(map(object({<br/>          key    = string<br/>          value  = optional(string)<br/>          effect = string<br/>          })), {<br/>          karpenter = {<br/>            key    = "karpenter.sh/controller"<br/>            value  = "true"<br/>            effect = "NO_SCHEDULE"<br/>          }<br/>        })<br/>      }), { enabled = false })<br/>    }), { enabled = false })<br/>  })</pre> | <pre>{<br/>  "enabled": true<br/>}</pre> | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (e.g. devnet, mainnet, testnet). | `string` | n/a | yes |
| <a name="input_kubernetes"></a> [kubernetes](#input\_kubernetes) | Kubernetes provider configuration. When eks.enabled = true these are resolved automatically from the EKS module. Set explicitly when bringing your own cluster. | <pre>object({<br/>    host                   = optional(string, null)<br/>    cluster_ca_certificate = optional(string, null)<br/>    cluster_name           = optional(string, null)<br/>  })</pre> | `{}` | no |
| <a name="input_networking"></a> [networking](#input\_networking) | VPC and subnet configuration. Set enabled = false to skip all networking resources. | <pre>object({<br/>    enabled = optional(bool, true)<br/><br/>    vpc = object({<br/>      cidr                     = string<br/>      availability_zones       = optional(list(string), [])<br/>      single_nat_gateway       = optional(bool, false)<br/>      use_subnet_calc_v2       = optional(bool, true)<br/>      private_subnet_cidr_mask = optional(number, 20)<br/>      public_subnet_cidr_mask  = optional(number, 24)<br/>      flow_log_enabled         = optional(bool, false)<br/>      flow_log_destination_arn = optional(string, null)<br/>    })<br/><br/>    additional_subnets = optional(object({<br/>      enabled        = optional(bool, false)<br/>      cidr_mask      = optional(number, 22)<br/>      expose_for_eks = optional(bool, false)<br/>      elb_role       = optional(string, null)<br/>      tags           = optional(map(string), {})<br/>      node_groups    = optional(list(string), [])<br/>    }), { enabled = false })<br/><br/>    # For usage of an existing VPC (bypasses networking module for RDS)<br/>    existing_vpc = optional(object({<br/>      vpc_id                     = string<br/>      private_subnet_ids         = list(string)<br/>      private_subnet_cidr_blocks = list(string)<br/>    }))<br/>  })</pre> | n/a | yes |
| <a name="input_partner_name"></a> [partner\_name](#input\_partner\_name) | Partner identifier — used as a name prefix across all resources. | `string` | n/a | yes |
| <a name="input_rds"></a> [rds](#input\_rds) | RDS instance configuration. Set enabled = false to skip. | <pre>object({<br/>    enabled = optional(bool, false)<br/><br/>    db_name             = optional(string, null)<br/>    identifier_override = optional(string, null)<br/><br/>    engine         = optional(string, "postgres")<br/>    engine_version = optional(string, "17")<br/><br/>    instance_class        = optional(string, "db.t4g.medium")<br/>    allocated_storage     = optional(number, 20)<br/>    max_allocated_storage = optional(number, 100)<br/>    multi_az              = optional(bool, false)<br/>    port                  = optional(number, 5432)<br/><br/>    username                        = optional(string, "postgres")<br/>    password                        = optional(string, null)<br/>    enable_master_password_rotation = optional(bool, false)<br/>    master_password_rotation_days   = optional(number, 7)<br/><br/>    maintenance_window      = optional(string, "Mon:00:00-Mon:03:00")<br/>    backup_retention_period = optional(number, 7)<br/>    deletion_protection     = optional(bool, true)<br/><br/>    monitoring_interval    = optional(number, 60)<br/>    create_monitoring_role = optional(bool, true)<br/>    monitoring_role_name   = optional(string, null)<br/>    monitoring_role_arn    = optional(string, null)<br/><br/>    parameters = optional(list(object({<br/>      name  = string<br/>      value = string<br/>    })), [])<br/><br/>    allowed_cidr_blocks = optional(list(string), [])<br/>  })</pre> | <pre>{<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_s3"></a> [s3](#input\_s3) | S3 configuration.<br/><br/>- buckets: Map of S3 buckets to create.<br/>  The map key is a short logical name (e.g. "coprocessor", "raw-data").<br/>  Each entry defines configuration and behavior for that bucket. | <pre>object({<br/>    buckets = map(object({<br/>      # Human-readable description (used for tagging)<br/>      purpose = string<br/><br/>      # Allow deletion even if objects exist<br/>      force_destroy = optional(bool, false)<br/><br/>      # Enable object versioning<br/>      versioning = optional(bool, true)<br/><br/>      # Public access configuration<br/>      public_access = optional(object({<br/>        enabled = bool<br/>        }), {<br/>        enabled = false<br/>      })<br/><br/>      # CORS configuration<br/>      cors = optional(object({<br/>        enabled         = bool<br/>        allowed_origins = list(string)<br/>        allowed_methods = list(string)<br/>        allowed_headers = list(string)<br/>        expose_headers  = list(string)<br/>        }), {<br/>        enabled         = false<br/>        allowed_origins = []<br/>        allowed_methods = []<br/>        allowed_headers = []<br/>        expose_headers  = []<br/>      })<br/><br/>      # Bucket policies<br/>      policy_statements = optional(list(object({<br/>        sid        = string<br/>        effect     = string<br/>        principals = map(list(string))<br/>        actions    = list(string)<br/>        resources  = list(string)<br/>        conditions = optional(list(object({<br/>          test     = string<br/>          variable = string<br/>          values   = list(string)<br/>        })), [])<br/>      })), [])<br/>    }))<br/>  })</pre> | <pre>{<br/>  "buckets": {}<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_additional_subnet_ids"></a> [additional\_subnet\_ids](#output\_additional\_subnet\_ids) | List of additional subnet IDs. |
| <a name="output_eks_cluster_certificate_authority_data"></a> [eks\_cluster\_certificate\_authority\_data](#output\_eks\_cluster\_certificate\_authority\_data) | Base64-encoded certificate authority data for the EKS cluster. |
| <a name="output_eks_cluster_endpoint"></a> [eks\_cluster\_endpoint](#output\_eks\_cluster\_endpoint) | The EKS cluster API endpoint. |
| <a name="output_eks_cluster_name"></a> [eks\_cluster\_name](#output\_eks\_cluster\_name) | The EKS cluster name. |
| <a name="output_eks_karpenter_iam_role_arn"></a> [eks\_karpenter\_iam\_role\_arn](#output\_eks\_karpenter\_iam\_role\_arn) | IAM role ARN for the Karpenter controller. |
| <a name="output_eks_karpenter_node_iam_role_arn"></a> [eks\_karpenter\_node\_iam\_role\_arn](#output\_eks\_karpenter\_node\_iam\_role\_arn) | IAM role ARN for Karpenter-managed nodes. |
| <a name="output_eks_karpenter_queue_name"></a> [eks\_karpenter\_queue\_name](#output\_eks\_karpenter\_queue\_name) | SQS queue name for Karpenter interruption handling. |
| <a name="output_eks_oidc_provider_arn"></a> [eks\_oidc\_provider\_arn](#output\_eks\_oidc\_provider\_arn) | The ARN of the OIDC provider for IRSA. |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | List of private subnet IDs. |
| <a name="output_rds_db_instance_address"></a> [rds\_db\_instance\_address](#output\_rds\_db\_instance\_address) | The RDS instance hostname (without port). |
| <a name="output_rds_db_instance_arn"></a> [rds\_db\_instance\_arn](#output\_rds\_db\_instance\_arn) | The ARN of the RDS instance. |
| <a name="output_rds_db_instance_endpoint"></a> [rds\_db\_instance\_endpoint](#output\_rds\_db\_instance\_endpoint) | The RDS instance connection endpoint (host:port). |
| <a name="output_rds_db_instance_identifier"></a> [rds\_db\_instance\_identifier](#output\_rds\_db\_instance\_identifier) | The identifier of the RDS instance. |
| <a name="output_rds_db_instance_port"></a> [rds\_db\_instance\_port](#output\_rds\_db\_instance\_port) | The port the RDS instance is listening on. |
| <a name="output_rds_security_group_id"></a> [rds\_security\_group\_id](#output\_rds\_security\_group\_id) | The ID of the RDS security group. |
| <a name="output_s3_bucket_arns"></a> [s3\_bucket\_arns](#output\_s3\_bucket\_arns) | Map of logical bucket key to bucket ARN. |
| <a name="output_s3_bucket_names"></a> [s3\_bucket\_names](#output\_s3\_bucket\_names) | Map of logical bucket key to bucket name. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | The ID of the VPC. |
<!-- END_TF_DOCS -->
