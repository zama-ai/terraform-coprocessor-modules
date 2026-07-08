<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.23 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.37.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 3.2.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_elasticache"></a> [elasticache](#module\_elasticache) | terraform-aws-modules/elasticache/aws | ~> 1.0 |

## Resources

| Name | Type |
|------|------|
| [kubernetes_service.externalname](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service) | resource |
| [aws_eks_cluster.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_subnet.cluster_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Optional EKS cluster name. When set, the VPC ID and private subnets<br/>(subnets with map\_public\_ip\_on\_launch = false) are auto-discovered from<br/>the cluster, so the module can be deployed as a standalone stack without<br/>wiring VPC outputs. Explicitly provided vpc\_id / private\_subnet\_ids /<br/>private\_subnet\_cidr\_blocks always take precedence over discovered values. | `string` | `null` | no |
| <a name="input_elasticache"></a> [elasticache](#input\_elasticache) | ElastiCache (Valkey/Redis) replication group configuration.<br/>Set enabled = false to skip all ElastiCache resources.<br/><br/>Two deployment profiles:<br/>  Testnet: node\_type = cache.r7g.large,   data\_tiering\_enabled = false (default)<br/>  Mainnet: node\_type = cache.r6gd.xlarge,  data\_tiering\_enabled = true | <pre>object({<br/>    enabled = optional(bool, false)<br/><br/>    # Naming<br/>    replication_group_id = optional(string, null) # override computed "{partner_name}-{environment}" identifier<br/><br/>    # Engine<br/>    engine         = optional(string, "valkey")<br/>    engine_version = optional(string, "7.2")<br/><br/>    # Instance<br/>    node_type            = optional(string, "cache.r7g.large")<br/>    num_cache_clusters   = optional(number, 3) # 1 primary + 2 replicas<br/>    port                 = optional(number, 6379)<br/>    data_tiering_enabled = optional(bool, false)<br/><br/>    # High availability<br/>    multi_az_enabled           = optional(bool, true)<br/>    automatic_failover_enabled = optional(bool, true)<br/><br/>    # Encryption<br/>    at_rest_encryption_enabled = optional(bool, true)<br/>    transit_encryption_enabled = optional(bool, true)<br/><br/>    # Auth<br/>    # NOTE: auth_token is stored in state as the AWS provider does not yet support write-only<br/>    # auth_token_wo for aws_elasticache_replication_group. Track upstream progress:<br/>    # https://github.com/hashicorp/terraform-provider-aws/pull/44260<br/>    auth_token = optional(string, null) # requires transit_encryption_enabled = true<br/><br/>    # Maintenance & backups<br/>    maintenance_window       = optional(string, "Mon:00:00-Mon:03:00")<br/>    snapshot_retention_limit = optional(number, 7)<br/>    snapshot_window          = optional(string, "03:00-05:00")<br/><br/>    # Parameters<br/>    parameters = optional(list(object({<br/>      name  = string<br/>      value = string<br/>    })), [])<br/><br/>    # Security group<br/>    additional_allowed_cidr_blocks = optional(list(string), [])<br/>  })</pre> | <pre>{<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (e.g. testnet, mainnet). | `string` | n/a | yes |
| <a name="input_externalname_service"></a> [externalname\_service](#input\_externalname\_service) | Optional Kubernetes ExternalName service that aliases the ElastiCache<br/>primary endpoint into the cluster (e.g. to expose it over Tailscale via<br/>annotations). Requires the kubernetes provider to be configured. Only<br/>created when both enabled = true and elasticache.enabled = true. | <pre>object({<br/>    enabled     = optional(bool, false)<br/>    name        = optional(string, "elasticache")<br/>    namespace   = optional(string, "default")<br/>    annotations = optional(map(string), {})<br/>  })</pre> | <pre>{<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_partner_name"></a> [partner\_name](#input\_partner\_name) | Partner identifier, used for resource naming. | `string` | n/a | yes |
| <a name="input_private_subnet_cidr_blocks"></a> [private\_subnet\_cidr\_blocks](#input\_private\_subnet\_cidr\_blocks) | CIDR blocks of private subnets, merged into ElastiCache security group ingress. Overrides CIDRs discovered from cluster\_name when non-empty. | `list(string)` | `[]` | no |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | List of private subnet IDs for the ElastiCache subnet group. Overrides subnets discovered from cluster\_name when non-empty. | `list(string)` | `[]` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID to deploy ElastiCache into. Overrides the value discovered from cluster\_name when set. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_externalname_service_name"></a> [externalname\_service\_name](#output\_externalname\_service\_name) | Name of the Kubernetes ExternalName service aliasing the primary endpoint, if created. |
| <a name="output_port"></a> [port](#output\_port) | The port the ElastiCache replication group is listening on. |
| <a name="output_primary_endpoint_address"></a> [primary\_endpoint\_address](#output\_primary\_endpoint\_address) | The primary endpoint address of the replication group. |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | The private subnet IDs used for the ElastiCache subnet group (explicit input or discovered from cluster\_name). |
| <a name="output_reader_endpoint_address"></a> [reader\_endpoint\_address](#output\_reader\_endpoint\_address) | The reader endpoint address of the replication group (load-balanced across replicas). |
| <a name="output_replication_group_arn"></a> [replication\_group\_arn](#output\_replication\_group\_arn) | The ARN of the ElastiCache replication group. |
| <a name="output_replication_group_id"></a> [replication\_group\_id](#output\_replication\_group\_id) | The ID of the ElastiCache replication group. |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | The ID of the ElastiCache security group. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | The VPC ID the ElastiCache replication group was deployed into (explicit input or discovered from cluster\_name). |
<!-- END_TF_DOCS -->