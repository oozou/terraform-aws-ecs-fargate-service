## Usage

```terraform
module "fargate_service" {
  source = "git::ssh://git@github.com/company/terraform-aws-ecs-fargate-service.git?ref=<version_or_branch>"

  # Generics
  prefix      = "customer"
  environment = "dev"
  name        = "demo"

  # IAM Role
  is_create_iam_role                             = true # Default is `true`
  exists_task_role_arn                           = ""   # Required when is_create_iam_role is `false`
  additional_ecs_task_role_policy_arns           = []   # Default is `[]`, already attaced ["arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"]
  exists_task_execution_role_arn                 = ""   # Required when is_create_iam_role is `false`
  additional_ecs_task_execution_role_policy_arns = []   # Default is `[]`, already attaced ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]

  # ALB
  is_attach_service_with_lb = true # Default is `true`
  ## If is_attach_service_with_lb is set to 'false,' the subsequent parameters are ignored.
  alb_listener_arn    = module.ecs_cluster.alb_listener_http_arn
  alb_paths           = ["/*"]                                     # List of alb path, default is [] will process as `["*"]` in module
  alb_priority        = "100"
  alb_host_header     = "demo-big.customer-develop.millenium-m.me" # Default is `null`
  custom_header_token = ""                                         # Default is `""`, specific for only allow header with given token ex. "asdskjhekewhdk"
  ## Target group that listener will take action
  vpc_id = module.vpc.vpc_id
  health_check = {
    interval            = 30
    path                = "/health"
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200,201,204"
  }

  # Logging
  is_create_cloudwatch_log_group   = true # Default is `true`
  cloudwatch_log_retention_in_days = 90   # Default is 90 days
  cloudwatch_log_kms_key_id        = null # Specify the kms to encrypt cloudwatch log

  # Task definition
  service_info = {
    containers_num = 2
    cpu_allocation = 256
    mem_allocation = 512
    port           = 8080
    image          = "nginx"
  }
  apm_sidecar_ecr_url = "" # Default is `""`. If specific, the APM is auto enable
  apm_config          = {} # There's default value, ignore if apm_sidecar_ecr_url is `""`

  # Secret
  secrets = {
    "DB_PASSWORD"         = "aa"
    "REDIS_PASSWORD"      = "vv"
    "API_SB_CRM_PASSWORD" = "cc"
    "S3_KMS_KEY_ID"       = "dd"
  }
  ## Optional json_secrets will create 1 asm in term of json; json_secrets -> {"name": "value", ...}
  json_secrets = {
    "DB_PASSWORD"         = "aa"
    "REDIS_PASSWORD"      = "vv"
    "API_SB_CRM_PASSWORD" = "cc"
    "S3_KMS_KEY_ID"       = "dd"
  }

  # ECS service
  ecs_cluster_name            = module.ecs_cluster.ecs_cluster_name
  service_discovery_namespace = module.ecs_cluster.service_discovery_namespace
  service_count               = 1     # Default is `1`
  is_enable_execute_command   = false # Default is `false`
  application_subnet_ids      = module.vpc.private_subnet_ids
  security_groups = [
    module.ecs_fargate_cluster.ecs_task_security_group_id,
    module.rds_mssql.db_client_security_group_id,
    module.redis.db_client_security_group_id
  ]

  # Auto Scaling Group
  scaling_configuration = {} #### See Below

  tags = {
    "Workspace" = "custom-workspace"
  }
}
```

### Target Tracking Policies

```terraform
scaling_configuration = {
  policy_type = "TargetTrackingScaling"
  capacity = {
    min_capacity = 1
    max_capacity = 10
  }
  scaling_behaviors = {
    cpu_average = {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
      target_value           = 60
      scale_in_cooldown      = 180
      scale_out_cooldown     = 60
    }
    memory_average = {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
      target_value           = 60
      scale_in_cooldown      = 180
      scale_out_cooldown     = 60
    }
  }
}
```

### Simple Policies

```terraform
scaling_configuration = {
  policy_type = "StepScaling"
  capacity = {
    min_capacity = 1
    max_capacity = 10
  }
  scaling_behaviors = {
    cpu_up_average = {
      metric_name         = "CPUUtilization"
      statistic           = "Average"
      comparison_operator = ">="
      threshold           = "65"
      period              = "60"
      evaluation_periods  = "1"
      cooldown            = 60
      scaling_adjustment  = 1
    }
    cpu_down_average = {
      metric_name         = "CPUUtilization"
      statistic           = "Average"
      comparison_operator = "<"
      threshold           = "50"
      period              = "60"
      evaluation_periods  = "10"
      cooldown            = 180
      scaling_adjustment  = -1
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name                                                                      | Version  |
|---------------------------------------------------------------------------|----------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws)                   | >= 4.00  |
| <a name="requirement_random"></a> [random](#requirement\_random)          | >= 2.3.0 |

## Providers

| Name                                                       | Version |
|------------------------------------------------------------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws)          | 4.15.1  |
| <a name="provider_random"></a> [random](#provider\_random) | 3.2.0   |

## Modules

| Name                                                                               | Source                                         | Version |
|------------------------------------------------------------------------------------|------------------------------------------------|---------|
| <a name="module_secret_kms_key"></a> [secret\_kms\_key](#module\_secret\_kms\_key) | git@github.com:oozou/terraform-aws-kms-key.git | v0.0.1  |

## Resources

| Name                                                                                                                                                                | Type        |
|---------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------|
| [aws_appautoscaling_policy.step_scaling_policies](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy)                | resource    |
| [aws_appautoscaling_policy.target_tracking_scaling_policies](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy)     | resource    |
| [aws_appautoscaling_target.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target)                                 | resource    |
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group)                                   | resource    |
| [aws_cloudwatch_metric_alarm.step_alarm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm)                       | resource    |
| [aws_ecs_service.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service)                                                     | resource    |
| [aws_ecs_task_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition)                                     | resource    |
| [aws_iam_role.task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)                                            | resource    |
| [aws_iam_role.task_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)                                                      | resource    |
| [aws_iam_role_policy.task_execution_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy)                           | resource    |
| [aws_iam_role_policy_attachment.task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment)        | resource    |
| [aws_iam_role_policy_attachment.task_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment)                  | resource    |
| [aws_lb_listener_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule)                                           | resource    |
| [aws_lb_target_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group)                                             | resource    |
| [aws_secretsmanager_secret.service_json_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret)                 | resource    |
| [aws_secretsmanager_secret.service_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret)                      | resource    |
| [aws_secretsmanager_secret_version.service_json_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource    |
| [aws_secretsmanager_secret_version.service_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version)      | resource    |
| [aws_service_discovery_service.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_service)                      | resource    |
| [random_string.service_secret_random_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string)                                 | resource    |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity)                                       | data source |
| [aws_iam_policy_document.task_assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)               | data source |
| [aws_iam_policy_document.task_execution_assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)     | data source |
| [aws_iam_role.get_ecs_task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_role)                                 | data source |
| [aws_iam_role.get_ecs_task_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_role)                                           | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region)                                                         | data source |

## Inputs

| Name                                                                                                                                                                                     | Description                                                                                                                                                                                                                                                                                         | Type                                                                                                                                                                                   | Default                                                                                 | Required |
|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------|:--------:|
| <a name="input_additional_ecs_task_execution_role_policy_arns"></a> [additional\_ecs\_task\_execution\_role\_policy\_arns](#input\_additional\_ecs\_task\_execution\_role\_policy\_arns) | List of policies ARNs to attach to the ECS Task Role. eg: { rds\_arn = module.postgres\_db.rds\_policy\_arn }                                                                                                                                                                                       | `list(string)`                                                                                                                                                                         | `[]`                                                                                    |    no    |
| <a name="input_additional_ecs_task_role_policy_arns"></a> [additional\_ecs\_task\_role\_policy\_arns](#input\_additional\_ecs\_task\_role\_policy\_arns)                                 | List of policies ARNs to attach to the ECS Task Role. eg: { rds\_arn = module.postgres\_db.rds\_policy\_arn }                                                                                                                                                                                       | `list(string)`                                                                                                                                                                         | `[]`                                                                                    |    no    |
| <a name="input_alb_host_header"></a> [alb\_host\_header](#input\_alb\_host\_header)                                                                                                      | Mention host header for api endpoint                                                                                                                                                                                                                                                                | `string`                                                                                                                                                                               | `null`                                                                                  |    no    |
| <a name="input_alb_listener_arn"></a> [alb\_listener\_arn](#input\_alb\_listener\_arn)                                                                                                   | The ALB listener to attach to                                                                                                                                                                                                                                                                       | `string`                                                                                                                                                                               | `""`                                                                                    |    no    |
| <a name="input_alb_paths"></a> [alb\_paths](#input\_alb\_paths)                                                                                                                          | Mention list Path For ALB routing eg: ["/"] or ["/route1"]                                                                                                                                                                                                                                          | `list(string)`                                                                                                                                                                         | `[]`                                                                                    |    no    |
| <a name="input_alb_priority"></a> [alb\_priority](#input\_alb\_priority)                                                                                                                 | Priority of ALB rule https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-listeners.html#listener-rules                                                                                                                                                                | `string`                                                                                                                                                                               | `"100"`                                                                                 |    no    |
| <a name="input_apm_config"></a> [apm\_config](#input\_apm\_config)                                                                                                                       | Config for X-Ray sidecar container for APM and traceability                                                                                                                                                                                                                                         | <pre>object({<br>    service_port = number<br>    cpu          = number<br>    memory       = number<br>  })</pre>                                                                     | <pre>{<br>  "cpu": 256,<br>  "memory": 512,<br>  "service_port": 9000<br>}</pre>        |    no    |
| <a name="input_apm_sidecar_ecr_url"></a> [apm\_sidecar\_ecr\_url](#input\_apm\_sidecar\_ecr\_url)                                                                                        | [Optional] To enable APM, set Sidecar ECR URL                                                                                                                                                                                                                                                       | `string`                                                                                                                                                                               | `""`                                                                                    |    no    |
| <a name="input_application_subnet_ids"></a> [application\_subnet\_ids](#input\_application\_subnet\_ids)                                                                                 | Subnet IDs to deploy into                                                                                                                                                                                                                                                                           | `list(string)`                                                                                                                                                                         | n/a                                                                                     |   yes    |
| <a name="input_cloudwatch_log_kms_key_id"></a> [cloudwatch\_log\_kms\_key\_id](#input\_cloudwatch\_log\_kms\_key\_id)                                                                    | The ARN for the KMS encryption key.                                                                                                                                                                                                                                                                 | `string`                                                                                                                                                                               | `null`                                                                                  |    no    |
| <a name="input_cloudwatch_log_retention_in_days"></a> [cloudwatch\_log\_retention\_in\_days](#input\_cloudwatch\_log\_retention\_in\_days)                                               | Retention day for cloudwatch log group                                                                                                                                                                                                                                                              | `number`                                                                                                                                                                               | `90`                                                                                    |    no    |
| <a name="input_custom_header_token"></a> [custom\_header\_token](#input\_custom\_header\_token)                                                                                          | [Required] Specify secret value for custom header                                                                                                                                                                                                                                                   | `string`                                                                                                                                                                               | `""`                                                                                    |    no    |
| <a name="input_ecs_cluster_name"></a> [ecs\_cluster\_name](#input\_ecs\_cluster\_name)                                                                                                   | ECS Cluster name to deploy in                                                                                                                                                                                                                                                                       | `string`                                                                                                                                                                               | n/a                                                                                     |   yes    |
| <a name="input_environment"></a> [environment](#input\_environment)                                                                                                                      | Environment Variable used as a prefix                                                                                                                                                                                                                                                               | `string`                                                                                                                                                                               | n/a                                                                                     |   yes    |
| <a name="input_envvars"></a> [envvars](#input\_envvars)                                                                                                                                  | List of [{name = "", value = ""}] pairs of environment variables                                                                                                                                                                                                                                    | <pre>set(object({<br>    name  = string<br>    value = string<br>  }))</pre>                                                                                                           | <pre>[<br>  {<br>    "name": "EXAMPLE_ENV",<br>    "value": "example"<br>  }<br>]</pre> |    no    |
| <a name="input_exists_task_execution_role_arn"></a> [exists\_task\_execution\_role\_arn](#input\_exists\_task\_execution\_role\_arn)                                                     | The existing arn of task exec role                                                                                                                                                                                                                                                                  | `string`                                                                                                                                                                               | `""`                                                                                    |    no    |
| <a name="input_exists_task_role_arn"></a> [exists\_task\_role\_arn](#input\_exists\_task\_role\_arn)                                                                                     | The existing arn of task role                                                                                                                                                                                                                                                                       | `string`                                                                                                                                                                               | `""`                                                                                    |    no    |
| <a name="input_health_check"></a> [health\_check](#input\_health\_check)                                                                                                                 | Health Check Config for the service                                                                                                                                                                                                                                                                 | `map(string)`                                                                                                                                                                          | `{}`                                                                                    |    no    |
| <a name="input_is_attach_service_with_lb"></a> [is\_attach\_service\_with\_lb](#input\_is\_attach\_service\_with\_lb)                                                                    | Attach the container to the public ALB? (true/false)                                                                                                                                                                                                                                                | `bool`                                                                                                                                                                                 | n/a                                                                                     |   yes    |
| <a name="input_is_create_cloudwatch_log_group"></a> [is\_create\_cloudwatch\_log\_group](#input\_is\_create\_cloudwatch\_log\_group)                                                     | Whether to create cloudwatch log group or not                                                                                                                                                                                                                                                       | `bool`                                                                                                                                                                                 | `true`                                                                                  |    no    |
| <a name="input_is_create_iam_role"></a> [is\_create\_iam\_role](#input\_is\_create\_iam\_role)                                                                                           | Create the built in IAM role for task role and task exec role                                                                                                                                                                                                                                       | `bool`                                                                                                                                                                                 | `true`                                                                                  |    no    |
| <a name="input_is_enable_execute_command"></a> [is\_enable\_execute\_command](#input\_is\_enable\_execute\_command)                                                                      | Specifies whether to enable Amazon ECS Exec for the tasks within the service.                                                                                                                                                                                                                       | `bool`                                                                                                                                                                                 | `false`                                                                                 |    no    |
| <a name="input_json_secrets"></a> [json\_secrets](#input\_json\_secrets)                                                                                                                 | Map of secret name(as reflected in Secrets Manager) and secret JSON string associated                                                                                                                                                                                                               | `map(string)`                                                                                                                                                                          | `{}`                                                                                    |    no    |
| <a name="input_name"></a> [name](#input\_name)                                                                                                                                           | Name of the ECS cluster to create                                                                                                                                                                                                                                                                   | `string`                                                                                                                                                                               | n/a                                                                                     |   yes    |
| <a name="input_prefix"></a> [prefix](#input\_prefix)                                                                                                                                     | The prefix name of customer to be displayed in AWS console and resource                                                                                                                                                                                                                             | `string`                                                                                                                                                                               | n/a                                                                                     |   yes    |
| <a name="input_scaling_configuration"></a> [scaling\_configuration](#input\_scaling\_configuration)                                                                                      | configuration of scaling configuration support both target tracking and step scaling policies<br>  https://docs.aws.amazon.com/autoscaling/application/APIReference/API_PredefinedMetricSpecification.html<br>  https://docs.aws.amazon.com/AmazonECS/latest/developerguide/cloudwatch-metrics.html | `any`                                                                                                                                                                                  | `{}`                                                                                    |    no    |
| <a name="input_secrets"></a> [secrets](#input\_secrets)                                                                                                                                  | Map of secret name(as reflected in Secrets Manager) and secret JSON string associated                                                                                                                                                                                                               | `map(string)`                                                                                                                                                                          | `{}`                                                                                    |    no    |
| <a name="input_security_groups"></a> [security\_groups](#input\_security\_groups)                                                                                                        | Security groups to apply to service                                                                                                                                                                                                                                                                 | `list(string)`                                                                                                                                                                         | n/a                                                                                     |   yes    |
| <a name="input_service_count"></a> [service\_count](#input\_service\_count)                                                                                                              | Number of containers to deploy                                                                                                                                                                                                                                                                      | `number`                                                                                                                                                                               | `1`                                                                                     |    no    |
| <a name="input_service_discovery_namespace"></a> [service\_discovery\_namespace](#input\_service\_discovery\_namespace)                                                                  | DNS Namespace to deploy to                                                                                                                                                                                                                                                                          | `string`                                                                                                                                                                               | n/a                                                                                     |   yes    |
| <a name="input_service_info"></a> [service\_info](#input\_service\_info)                                                                                                                 | The configuration of service                                                                                                                                                                                                                                                                        | <pre>object({<br>    cpu_allocation = number<br>    mem_allocation = number<br>    containers_num = number<br>    port           = number<br>    image          = string<br>  })</pre> | n/a                                                                                     |   yes    |
| <a name="input_tags"></a> [tags](#input\_tags)                                                                                                                                           | Custom tags which can be passed on to the AWS resources. They should be key value pairs having distinct keys                                                                                                                                                                                        | `map(any)`                                                                                                                                                                             | `{}`                                                                                    |    no    |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id)                                                                                                                                   | VPC id where security group is created                                                                                                                                                                                                                                                              | `string`                                                                                                                                                                               | `""`                                                                                    |    no    |

## Outputs

| Name                                                                                                            | Description                                     |
|-----------------------------------------------------------------------------------------------------------------|-------------------------------------------------|
| <a name="output_secret_arns"></a> [secret\_arns](#output\_secret\_arns)                                         | List of ARNs of the SecretsManager secrets      |
| <a name="output_secret_json_arn"></a> [secret\_json\_arn](#output\_secret\_json\_arn)                           | List of ARNs of the SecretsManager json secrets |
| <a name="output_task_execution_role_arn"></a> [task\_execution\_role\_arn](#output\_task\_execution\_role\_arn) | ECS Task execution role ARN                     |
| <a name="output_task_execution_role_id"></a> [task\_execution\_role\_id](#output\_task\_execution\_role\_id)    | ECS Task execution role ID                      |
| <a name="output_task_role_arn"></a> [task\_role\_arn](#output\_task\_role\_arn)                                 | ECS Task role ARN                               |
| <a name="output_task_role_id"></a> [task\_role\_id](#output\_task\_role\_id)                                    | ECS Task role ID                                |
<!-- END_TF_DOCS -->
