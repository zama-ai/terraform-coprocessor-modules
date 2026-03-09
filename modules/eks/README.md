<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | ~> 21.0.6 |
| <a name="module_karpenter"></a> [karpenter](#module\_karpenter) | terraform-aws-modules/eks/aws//modules/karpenter | ~> 21.0 |

## Resources

| Name | Type |
|------|------|
| [aws_eks_access_entry.admin_roles](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry) | resource |
| [aws_eks_access_policy_association.admin_roles](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_policy_association) | resource |
| [aws_iam_policy.karpenter_encryption](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.karpenter_instance_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role_policy_attachment.karpenter_encryption](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.karpenter_instance_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_service_linked_role.spot](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_service_linked_role) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_subnet_ids"></a> [additional\_subnet\_ids](#input\_additional\_subnet\_ids) | Additional subnet IDs for node groups that require them. | `list(string)` | `[]` | no |
| <a name="input_addons"></a> [addons](#input\_addons) | EKS addon configuration. | <pre>object({<br/>    defaults = optional(map(any), {<br/>      aws-ebs-csi-driver     = { most_recent = true }<br/>      coredns                = { most_recent = true }<br/>      vpc-cni                = { most_recent = true, before_compute = true }<br/>      kube-proxy             = { most_recent = true }<br/>      eks-pod-identity-agent = { most_recent = true }<br/>    })<br/>    extra = optional(map(any), {})<br/><br/>    vpc_cni_config = optional(object({<br/>      init = optional(object({<br/>        env = optional(object({<br/>          DISABLE_TCP_EARLY_DEMUX = optional(string, "true")<br/>        }), {})<br/>      }), {})<br/>      env = optional(object({<br/>        ENABLE_POD_ENI                    = optional(string, "true")<br/>        POD_SECURITY_GROUP_ENFORCING_MODE = optional(string, "standard")<br/>        ENABLE_PREFIX_DELEGATION          = optional(string, "true")<br/>        WARM_PREFIX_TARGET                = optional(string, "1")<br/>      }), {})<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_cluster"></a> [cluster](#input\_cluster) | EKS cluster configuration. | <pre>object({<br/>    version       = optional(string, "1.32")<br/>    name_override = optional(string, null)<br/><br/>    endpoint_public_access       = optional(bool, false)<br/>    endpoint_private_access      = optional(bool, true)<br/>    endpoint_public_access_cidrs = optional(list(string), [])<br/><br/>    enable_irsa                        = optional(bool, true)<br/>    enable_creator_admin_permissions   = optional(bool, true)<br/><br/>    admin_role_arns = optional(list(string), [])<br/>  })</pre> | `{}` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (e.g. devnet, mainnet, testnet). | `string` | n/a | yes |
| <a name="input_karpenter"></a> [karpenter](#input\_karpenter) | Karpenter configuration. Set enabled = false to skip all Karpenter resources. | <pre>object({<br/>    enabled          = optional(bool, false)<br/>    namespace        = optional(string, "karpenter")<br/>    service_account  = optional(string, "karpenter")<br/>    queue_name       = optional(string, null)<br/>    rule_name_prefix = optional(string, null)<br/><br/>    node_iam_role_additional_policies = optional(map(string), {<br/>      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"<br/>    })<br/><br/>    controller_nodegroup = optional(object({<br/>      enabled        = optional(bool, false)<br/>      capacity_type  = optional(string, "ON_DEMAND")<br/>      min_size       = optional(number, 1)<br/>      max_size       = optional(number, 2)<br/>      desired_size   = optional(number, 1)<br/>      instance_types = optional(list(string), ["t3.small"])<br/>      ami_type       = optional(string, "AL2023_x86_64_STANDARD")<br/>      disk_size      = optional(number, 50)<br/>      disk_type      = optional(string, "gp3")<br/>      labels         = optional(map(string), { "karpenter.sh/controller" = "true" })<br/>      taints = optional(map(object({<br/>        key    = string<br/>        value  = optional(string)<br/>        effect = string<br/>      })), {<br/>        karpenter = {<br/>          key    = "karpenter.sh/controller"<br/>          value  = "true"<br/>          effect = "NO_SCHEDULE"<br/>        }<br/>      })<br/>    }), { enabled = false })<br/>  })</pre> | <pre>{<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for all EKS resources. | `string` | n/a | yes |
| <a name="input_node_groups"></a> [node\_groups](#input\_node\_groups) | EKS managed node group configuration. | <pre>object({<br/>    defaults = optional(map(any), {})<br/><br/>    default_iam_policies = optional(map(string), {<br/>      AmazonEBSCSIDriverPolicy           = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"<br/>      AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"<br/>      AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"<br/>    })<br/><br/>    groups = optional(map(object({<br/>      capacity_type              = optional(string, "ON_DEMAND")<br/>      min_size                   = optional(number, 1)<br/>      max_size                   = optional(number, 3)<br/>      desired_size               = optional(number, 1)<br/>      instance_types             = optional(list(string), ["t3.medium"])<br/>      ami_type                   = optional(string, "AL2023_x86_64_STANDARD")<br/>      use_custom_launch_template = optional(bool, false)<br/>      disk_size                  = optional(number, 30)<br/>      disk_type                  = optional(string, "gp3")<br/>      labels                     = optional(map(string), {})<br/>      tags                       = optional(map(string), {})<br/>      use_additional_subnets     = optional(bool, false)<br/>      update_config = optional(object({<br/>        max_unavailable            = optional(number)<br/>        max_unavailable_percentage = optional(number)<br/>      }), { max_unavailable = 1 })<br/>      taints = optional(map(object({<br/>        key    = string<br/>        value  = optional(string)<br/>        effect = string<br/>      })), {})<br/>      iam_role_additional_policies = optional(map(string), {})<br/>      metadata_options = optional(map(string), {<br/>        http_endpoint               = "enabled"<br/>        http_put_response_hop_limit = "2"<br/>        http_tokens                 = "required"<br/>      })<br/>    })), {<br/>      default = {<br/>        capacity_type  = "ON_DEMAND"<br/>        min_size       = 1<br/>        max_size       = 3<br/>        desired_size   = 1<br/>        instance_types = ["t3.medium"]<br/>        disk_size      = 30<br/>        update_config  = { max_unavailable = 1 }<br/>      }<br/>    })<br/>  })</pre> | `{}` | no |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | Private subnet IDs for the EKS control plane and default node groups. | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID to deploy the cluster into. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | Base64-encoded certificate authority data for the cluster. |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | EKS cluster API server endpoint. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | EKS cluster name. |
| <a name="output_karpenter_iam_role_arn"></a> [karpenter\_iam\_role\_arn](#output\_karpenter\_iam\_role\_arn) | Karpenter controller IAM role ARN. Null when Karpenter is disabled. |
| <a name="output_karpenter_node_iam_role_arn"></a> [karpenter\_node\_iam\_role\_arn](#output\_karpenter\_node\_iam\_role\_arn) | IAM role ARN attached to Karpenter-launched nodes. Null when Karpenter is disabled. |
| <a name="output_karpenter_queue_name"></a> [karpenter\_queue\_name](#output\_karpenter\_queue\_name) | SQS queue name for Karpenter interruption handling. Null when Karpenter is disabled. |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ARN of the OIDC provider for IRSA. |
<!-- END_TF_DOCS -->
