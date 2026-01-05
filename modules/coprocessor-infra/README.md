# Coprocessor Terraform Module

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.23 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.23 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_iam_assumable_role_coprocessor"></a> [iam\_assumable\_role\_coprocessor](#module\_iam\_assumable\_role\_coprocessor) | terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc | 5.48.0 |
| <a name="module_rds_instance"></a> [rds\_instance](#module\_rds\_instance) | terraform-aws-modules/rds/aws | ~> 6.10 |
| <a name="module_rds_security_group"></a> [rds\_security\_group](#module\_rds\_security\_group) | terraform-aws-modules/security-group/aws | ~> 5.3.0 |

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.coprocessor_aws](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_s3_bucket.coprocessor_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_cors_configuration.coprocessor_bucket_cors](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_cors_configuration) | resource |
| [aws_s3_bucket_ownership_controls.coprocessor_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.coprocessor_bucket_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.coprocessor_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_versioning.coprocessor_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [kubernetes_namespace.coprocessor_namespace](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_service.externalname](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service) | resource |
| [kubernetes_service_account.coprocessor_service_account](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [random_id.coprocessor_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [aws_eks_cluster.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_subnet.cluster_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket_prefix"></a> [bucket\_prefix](#input\_bucket\_prefix) | The prefix for the S3 bucket names | `string` | `"coprocessor-bucket"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the EKS cluster for IRSA configuration | `string` | n/a | yes |
| <a name="input_coprocessor_role_name"></a> [coprocessor\_role\_name](#input\_coprocessor\_role\_name) | The name of the IAM role for the coprocessor | `string` | `""` | no |
| <a name="input_create_coprocessor_namespace"></a> [create\_coprocessor\_namespace](#input\_create\_coprocessor\_namespace) | Whether to create the Kubernetes namespace | `bool` | `true` | no |
| <a name="input_create_service_account"></a> [create\_service\_account](#input\_create\_service\_account) | Whether to create the Kubernetes service account (should be false when using IRSA as IRSA creates it) | `bool` | `true` | no |
| <a name="input_enable_rds"></a> [enable\_rds](#input\_enable\_rds) | Whether to create the RDS instance | `bool` | `true` | no |
| <a name="input_k8s_coprocessor_namespace"></a> [k8s\_coprocessor\_namespace](#input\_k8s\_coprocessor\_namespace) | The Kubernetes namespace for coprocessor resources | `string` | `"coprocessor"` | no |
| <a name="input_k8s_coprocessor_service_account_name"></a> [k8s\_coprocessor\_service\_account\_name](#input\_k8s\_coprocessor\_service\_account\_name) | The name of the Kubernetes service account for Coprocessor party | `string` | n/a | yes |
| <a name="input_namespace_annotations"></a> [namespace\_annotations](#input\_namespace\_annotations) | Additional annotations to apply to the namespace | `map(string)` | `{}` | no |
| <a name="input_namespace_labels"></a> [namespace\_labels](#input\_namespace\_labels) | Additional labels to apply to the namespace | `map(string)` | `{}` | no |
| <a name="input_network_environment"></a> [network\_environment](#input\_network\_environment) | Coprocessor network environment that determines region constraints | `string` | `"testnet"` | no |
| <a name="input_rds_allocated_storage"></a> [rds\_allocated\_storage](#input\_rds\_allocated\_storage) | Allocated storage in GiB. | `number` | `20` | no |
| <a name="input_rds_allowed_cidr_blocks"></a> [rds\_allowed\_cidr\_blocks](#input\_rds\_allowed\_cidr\_blocks) | CIDR blocks allowed to reach the database port. | `list(string)` | `[]` | no |
| <a name="input_rds_backup_retention_period"></a> [rds\_backup\_retention\_period](#input\_rds\_backup\_retention\_period) | Number of days to retain RDS automated backups (0 to 35) | `number` | `7` | no |
| <a name="input_rds_create_externalname_service"></a> [rds\_create\_externalname\_service](#input\_rds\_create\_externalname\_service) | Whether to create a Kubernetes ExternalName service for RDS database access | `bool` | `false` | no |
| <a name="input_rds_create_monitoring_role"></a> [rds\_create\_monitoring\_role](#input\_rds\_create\_monitoring\_role) | Whether to create the RDS monitoring role | `bool` | `true` | no |
| <a name="input_rds_db_name"></a> [rds\_db\_name](#input\_rds\_db\_name) | Optional initial database name. | `string` | `"coprocessor"` | no |
| <a name="input_rds_db_password"></a> [rds\_db\_password](#input\_rds\_db\_password) | RDS password to be set from inputs (must be longer than 8 chars), will disable RDS automatic SecretManager password | `string` | `null` | no |
| <a name="input_rds_deletion_protection"></a> [rds\_deletion\_protection](#input\_rds\_deletion\_protection) | Whether to enable deletion protection for RDS instance | `bool` | `false` | no |
| <a name="input_rds_enable_master_password_rotation"></a> [rds\_enable\_master\_password\_rotation](#input\_rds\_enable\_master\_password\_rotation) | Whether to manage the master user password rotation. By default, false on creation, rotation is managed by RDS. There is not currently no way to disable this on initial creation even when set to false. Setting this value to false after previously having been set to true will disable automatic rotation. | `bool` | `true` | no |
| <a name="input_rds_engine"></a> [rds\_engine](#input\_rds\_engine) | Engine name (e.g., postgres, mysql). | `string` | `"postgres"` | no |
| <a name="input_rds_engine_version"></a> [rds\_engine\_version](#input\_rds\_engine\_version) | Exact engine version string. | `string` | `"17.2"` | no |
| <a name="input_rds_externalname_service_annotations"></a> [rds\_externalname\_service\_annotations](#input\_rds\_externalname\_service\_annotations) | Annotations to apply to the Kubernetes ExternalName service for RDS database | `map(string)` | `{}` | no |
| <a name="input_rds_externalname_service_name"></a> [rds\_externalname\_service\_name](#input\_rds\_externalname\_service\_name) | Name of the Kubernetes ExternalName service for RDS database | `string` | `"coprocessor-db-external"` | no |
| <a name="input_rds_externalname_service_namespace"></a> [rds\_externalname\_service\_namespace](#input\_rds\_externalname\_service\_namespace) | Kubernetes namespace for the RDS ExternalName service | `string` | `"coprocessor"` | no |
| <a name="input_rds_identifier_override"></a> [rds\_identifier\_override](#input\_rds\_identifier\_override) | Explicit DB identifier. If null, a normalized name is derived from prefix+environment+identifier. | `string` | `null` | no |
| <a name="input_rds_instance_class"></a> [rds\_instance\_class](#input\_rds\_instance\_class) | DB instance class (e.g., db.t4g.medium). | `string` | `"db.t3.micro"` | no |
| <a name="input_rds_maintenance_window"></a> [rds\_maintenance\_window](#input\_rds\_maintenance\_window) | Weekly maintenance window for RDS instance (e.g., 'sun:05:00-sun:06:00') | `string` | `null` | no |
| <a name="input_rds_master_password_rotation_days"></a> [rds\_master\_password\_rotation\_days](#input\_rds\_master\_password\_rotation\_days) | Number of days between automatic scheduled rotations of the secret, default is set to the maximum allowed value of 1000 days | `number` | `1000` | no |
| <a name="input_rds_max_allocated_storage"></a> [rds\_max\_allocated\_storage](#input\_rds\_max\_allocated\_storage) | Max autoscaled storage in GiB. | `number` | `1000` | no |
| <a name="input_rds_monitoring_interval"></a> [rds\_monitoring\_interval](#input\_rds\_monitoring\_interval) | Enhanced monitoring interval in seconds (0, 1, 5, 10, 15, 30, 60) | `number` | `0` | no |
| <a name="input_rds_monitoring_role_arn"></a> [rds\_monitoring\_role\_arn](#input\_rds\_monitoring\_role\_arn) | ARN of IAM role for RDS enhanced monitoring (required if monitoring\_interval > 0) | `string` | `null` | no |
| <a name="input_rds_monitoring_role_name"></a> [rds\_monitoring\_role\_name](#input\_rds\_monitoring\_role\_name) | Name of the monitoring role to create | `string` | `"rds-monitoring-role"` | no |
| <a name="input_rds_multi_az"></a> [rds\_multi\_az](#input\_rds\_multi\_az) | Whether to enable Multi-AZ deployment for RDS instance for high availability | `bool` | `false` | no |
| <a name="input_rds_parameters"></a> [rds\_parameters](#input\_rds\_parameters) | List of DB parameter maps for the parameter group. | `list(map(string))` | <pre>[<br/>  {<br/>    "name": "rds.force_ssl",<br/>    "value": "0"<br/>  }<br/>]</pre> | no |
| <a name="input_rds_port"></a> [rds\_port](#input\_rds\_port) | Port for the RDS instance | `number` | `5432` | no |
| <a name="input_rds_prefix"></a> [rds\_prefix](#input\_rds\_prefix) | Name organization prefix (e.g., 'zama'). | `string` | `"zama"` | no |
| <a name="input_rds_username"></a> [rds\_username](#input\_rds\_username) | Username for the RDS instance | `string` | `"zws"` | no |
| <a name="input_rds_vpc_id"></a> [rds\_vpc\_id](#input\_rds\_vpc\_id) | VPC ID hosting the RDS instance. | `string` | `null` | no |
| <a name="input_service_account_annotations"></a> [service\_account\_annotations](#input\_service\_account\_annotations) | Additional annotations to apply to the service account (excluding IRSA annotations which are handled automatically) | `map(string)` | `{}` | no |
| <a name="input_service_account_labels"></a> [service\_account\_labels](#input\_service\_account\_labels) | Additional labels to apply to the service account | `map(string)` | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to the resource | `map(string)` | <pre>{<br/>  "module": "coprocessor-infra",<br/>  "terraform": "true"<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_coprocessor_bucket_storage_summary"></a> [coprocessor\_bucket\_storage\_summary](#output\_coprocessor\_bucket\_storage\_summary) | Summary of the coprocessor bucket storage |
| <a name="output_k8s_coprocessor_service_account_summary"></a> [k8s\_coprocessor\_service\_account\_summary](#output\_k8s\_coprocessor\_service\_account\_summary) | Summary of the Kubernetes service account for Coprocessor party |
| <a name="output_rds_summary"></a> [rds\_summary](#output\_rds\_summary) | Aggregated RDS database information |
<!-- END_TF_DOCS -->
