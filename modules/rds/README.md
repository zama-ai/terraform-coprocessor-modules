<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_rds_instance"></a> [rds\_instance](#module\_rds\_instance) | terraform-aws-modules/rds/aws | ~> 6.10 |
| <a name="module_rds_security_group"></a> [rds\_security\_group](#module\_rds\_security\_group) | terraform-aws-modules/security-group/aws | ~> 5.3.0 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (e.g. devnet, mainnet, testnet). | `string` | n/a | yes |
| <a name="input_partner_name"></a> [partner\_name](#input\_partner\_name) | Partner identifier, used for resource naming. | `string` | n/a | yes |
| <a name="input_private_subnet_cidr_blocks"></a> [private\_subnet\_cidr\_blocks](#input\_private\_subnet\_cidr\_blocks) | CIDR blocks of private subnets, merged into RDS security group ingress. | `list(string)` | `[]` | no |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | List of private subnet IDs for the RDS subnet group. | `list(string)` | `[]` | no |
| <a name="input_rds"></a> [rds](#input\_rds) | RDS instance configuration. Set enabled = false to skip all RDS resources. | <pre>object({<br/>    enabled = optional(bool, false)<br/><br/>    # Naming<br/>    db_name             = optional(string, null)<br/>    identifier_override = optional(string, null)<br/><br/>    # Engine<br/>    engine         = optional(string, "postgres")<br/>    engine_version = optional(string, "17")<br/><br/>    # Instance<br/>    instance_class        = optional(string, "db.t4g.medium")<br/>    allocated_storage     = optional(number, 20)<br/>    max_allocated_storage = optional(number, 100)<br/>    multi_az              = optional(bool, false)<br/>    port                  = optional(number, 5432)<br/><br/>    # Credentials<br/>    username                        = optional(string, "postgres")<br/>    password                        = optional(string, null) # null = Secrets Manager managed<br/>    enable_master_password_rotation = optional(bool, false)<br/>    master_password_rotation_days   = optional(number, 7)<br/><br/>    # Maintenance & backups<br/>    maintenance_window      = optional(string, "Mon:00:00-Mon:03:00")<br/>    backup_retention_period = optional(number, 7)<br/>    deletion_protection     = optional(bool, true)<br/><br/>    # Monitoring<br/>    monitoring_interval    = optional(number, 60)<br/>    create_monitoring_role = optional(bool, true)<br/>    monitoring_role_name   = optional(string, null)<br/>    monitoring_role_arn    = optional(string, null)<br/><br/>    # Parameters<br/>    parameters = optional(list(object({<br/>      name  = string<br/>      value = string<br/>    })), [])<br/><br/>    # Security group<br/>    allowed_cidr_blocks = optional(list(string), [])<br/>  })</pre> | <pre>{<br/>  "db_name": "",<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID to deploy RDS into. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_db_instance_address"></a> [db\_instance\_address](#output\_db\_instance\_address) | The hostname of the RDS instance (without port). |
| <a name="output_db_instance_arn"></a> [db\_instance\_arn](#output\_db\_instance\_arn) | The ARN of the RDS instance. |
| <a name="output_db_instance_endpoint"></a> [db\_instance\_endpoint](#output\_db\_instance\_endpoint) | The connection endpoint of the RDS instance (host:port). |
| <a name="output_db_instance_identifier"></a> [db\_instance\_identifier](#output\_db\_instance\_identifier) | The RDS instance identifier. |
| <a name="output_db_instance_name"></a> [db\_instance\_name](#output\_db\_instance\_name) | The name of the default database. |
| <a name="output_db_instance_port"></a> [db\_instance\_port](#output\_db\_instance\_port) | The port the RDS instance is listening on. |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | The ID of the RDS security group. |
<!-- END_TF_DOCS -->
