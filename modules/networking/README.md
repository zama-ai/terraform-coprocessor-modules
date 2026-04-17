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

| Name | Source | Version |
|------|--------|---------|
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | ~> 6.0 |

## Resources

| Name | Type |
|------|------|
| [aws_route_table_association.additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_subnet.additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_subnets"></a> [additional\_subnets](#input\_additional\_subnets) | Optional additional subnets, e.g. for CNI or specific node groups. | <pre>object({<br/>    enabled   = optional(bool, false)<br/>    cidr_mask = optional(number, 22)<br/><br/>    # EKS integration<br/>    expose_for_eks = optional(bool, false)  # add karpenter.sh/discovery tag<br/>    elb_role       = optional(string, null) # "internal" | "public" | null<br/>    tags           = optional(map(string), {})<br/>  })</pre> | <pre>{<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_eks_cluster_name"></a> [eks\_cluster\_name](#input\_eks\_cluster\_name) | EKS cluster name, used for subnet discovery tags. | `string` | n/a | yes |
| <a name="input_enable_karpenter"></a> [enable\_karpenter](#input\_enable\_karpenter) | Whether Karpenter is enabled — affects subnet discovery tags. | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (e.g. testnet, mainnet). | `string` | n/a | yes |
| <a name="input_partner_name"></a> [partner\_name](#input\_partner\_name) | Name prefix for all networking resources. | `string` | n/a | yes |
| <a name="input_vpc"></a> [vpc](#input\_vpc) | VPC and subnet configuration. | <pre>object({<br/>    # Base<br/>    cidr               = string<br/>    availability_zones = optional(list(string), []) # leave empty to auto-discover AZs<br/>    single_nat_gateway = optional(bool, false)      # true = one NAT GW shared across AZs (cheaper, less resilient)<br/><br/>    # Subnet CIDR calculation<br/>    private_subnet_cidr_mask = optional(number, 20)<br/>    public_subnet_cidr_mask  = optional(number, 20)<br/><br/>    # Flow logs<br/>    flow_log_enabled         = optional(bool, false)<br/>    flow_log_destination_arn = optional(string, null)<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_additional_subnet_ids"></a> [additional\_subnet\_ids](#output\_additional\_subnet\_ids) | List of additional subnet IDs (empty list when not enabled). |
| <a name="output_private_subnet_cidr_blocks"></a> [private\_subnet\_cidr\_blocks](#output\_private\_subnet\_cidr\_blocks) | CIDR blocks of private subnets. |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | List of private subnet IDs. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | VPC ID. |
<!-- END_TF_DOCS -->
