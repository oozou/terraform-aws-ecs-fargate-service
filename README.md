# Terraform AWS ECS Fargate Service Module

## TargetTrackingScaling 

```tf
  # Predefined Metrics
  target_tracking_configuration = {
    policy_type = "TargetTrackingScaling"
    name        = "cpu-average"
    capacity = {
      min_capacity = 1
      max_capacity = 10
    }
    scaling_behaviors = {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
      target_value           = 60
      scale_in_cooldown      = 180
      scale_out_cooldown     = 60
    }
  }

  # Customization Metrics
  target_tracking_configuration = {
    policy_type = "TargetTrackingScaling"
    name        = "concurrency-per-task"
    capacity = {
      min_capacity = 1
      max_capacity = 10
    }
    scaling_behaviors = {
      target_value       = 1500
      scale_in_cooldown  = 180
      scale_out_cooldown = 60
      custom_metrics = {
        active_connection_count = {
          id          = "acc"
          label       = "Get value of ActiveConnectionCount metric"
          return_data = false
          metric_stat = {
            stat        = "Sum"
            metric_name = "ActiveConnectionCount"
            namespace   = "AWS/ApplicationELB"
            dimensions = [
              {
                name  = "LoadBalancer"
                value = "app/oozou-devops-demo-alb/f0f65a9c9ea681e0"
              }
            ]
          }
        }
        running_task_count = {
          id          = "rtc"
          label       = "Get value of RunningTaskCount metric"
          return_data = false
          metric_stat = {
            stat        = "Average"
            metric_name = "RunningTaskCount"
            namespace   = "ECS/ContainerInsights"
            dimensions = [
              {
                name  = "ServiceName"
                value = "oozou-devops-demo-service-api"
              },
              {
                name  = "ClusterName"
                value = "oozou-devops-demo-cluster"
              },
            ]
          }
        }
        scaling_expression = {
          id          = "e1"
          label       = "ActiveConnectionCount/RunningTaskCount"
          expression  = "(acc)/rtc"
          return_data = true
        }
      }
    }
  }
```

## StepScaling

```tf
  # Predefined Metrics
  step_scaling_configuration = {
    policy_type = "StepScaling"
    capacity = {
      min_capacity = 1
      max_capacity = 10
    }
    scaling_behaviors = {
      cpu_up = {
        metric_name         = "CPUUtilization"
        namespace           = "AWS/ECS"
        statistic           = "Average"
        comparison_operator = ">="
        threshold           = "60"
        period              = "60"
        evaluation_periods  = "1"
        cooldown            = 60
        # If value in (threshold+lower_bound, threshold+upper_bound), in crease scaling_adjustment
        step_adjustment = [
          {
            # (60, 80) increase 1
            metric_interval_lower_bound = 0
            metric_interval_upper_bound = 20
            scaling_adjustment          = 1
          },
          {
            # (80, n) increase 2
            metric_interval_lower_bound = 20
            scaling_adjustment          = 2
          }
        ]
      }
      cpu_down = {
        metric_name         = "CPUUtilization"
        namespace           = "AWS/ECS"
        statistic           = "Average"
        comparison_operator = "<="
        threshold           = "40"
        period              = "60"
        evaluation_periods  = "2"
        cooldown            = 120
        step_adjustment = [
          # If value in (threshold+lower_bound, threshold+upper_bound), in crease scaling_adjustment
          {
            metric_interval_upper_bound = 0.0
            scaling_adjustment          = -1
          }
        ]
      }
    }
  }

  # Customization Metrics
  step_scaling_configuration = {
    policy_type = "StepScaling"
    capacity = {
      min_capacity = 1
      max_capacity = 2
    }
    scaling_behaviors = {
      scaling_up = {
        metric_query = [
          {
            id = "acc"
            metric = [
              {
                metric_name = "ActiveConnectionCount"
                namespace   = "AWS/ApplicationELB"
                period      = "60"
                stat        = "Sum"
                dimensions = {
                  LoadBalancer = "app/oozou-dev-cms-alb/8c877c9bfb7aede3"
                }
              }
            ]
          },
          {
            id = "rtc"
            metric = [
              {
                metric_name = "RunningTaskCount"
                namespace   = "ECS/ContainerInsights"
                period      = "60"
                stat        = "Average"
                dimensions = {
                  ClusterName = "oozou-devops-demo-cluster"
                  ServiceName = "oozou-devops-demo-service-api"
                }
              }
            ]
          },
          {
            id          = "e1"
            expression  = "(acc*10)/rtc"
            label       = "ActiveConnectionCount/RunningTaskCount"
            return_data = true
          }
        ]
        statistic           = "Average"
        comparison_operator = ">="
        evaluation_periods  = "1"
        threshold           = 1500
        cooldown            = 60
        # If value in (threshold+lower_bound, threshold+upper_bound), in crease scaling_adjustment
        step_adjustment = [
          {
            # (1500, 2500) increase 1
            metric_interval_lower_bound = 0
            metric_interval_upper_bound = 1000
            scaling_adjustment          = 1
          },
          {
            # (2500, 4500) increase 2
            metric_interval_lower_bound = 1000
            metric_interval_upper_bound = 3000
            scaling_adjustment          = 2
          },
          {
            # (4500, n) increase 4
            metric_interval_lower_bound = 3000
            scaling_adjustment          = 4
          }
        ]
      }
      scaling_down = {
        metric_query = [
          {
            id = "acc"
            metric = [
              {
                metric_name = "ActiveConnectionCount"
                namespace   = "AWS/ApplicationELB"
                period      = "60"
                stat        = "Sum"
                dimensions = {
                  LoadBalancer = "app/oozou-dev-cms-alb/8c877c9bfb7aede3"
                }
              }
            ]
          },
          {
            id = "rtc"
            metric = [
              {
                metric_name = "RunningTaskCount"
                namespace   = "ECS/ContainerInsights"
                period      = "60"
                stat        = "Average"
                dimensions = {
                  ClusterName = "oozou-devops-demo-cluster"
                  ServiceName = "oozou-devops-demo-service-api"
                }
              }
            ]
          },
          {
            id          = "e1"
            expression  = "(acc*10)/rtc"
            label       = "ActiveConnectionCount/RunningTaskCount"
            return_data = true
          }
        ]
        statistic           = "Average"
        comparison_operator = "<="
        evaluation_periods  = "1"
        threshold           = 1300
        cooldown            = 300
        # If value in (threshold+lower_bound, threshold+upper_bound), in crease scaling_adjustment
        step_adjustment = [
          {
            # (0, 1300) increase 1
            metric_interval_upper_bound = 0
            scaling_adjustment          = -1
          }
        ]
      }
    }
  }
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name                                                                      | Version  |
|---------------------------------------------------------------------------|----------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws)                   | >= 4.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random)          | >= 2.3.0 |

## Providers

| Name                                                       | Version |
|------------------------------------------------------------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws)          | 5.22.0  |
| <a name="provider_random"></a> [random](#provider\_random) | 3.5.1   |

## Modules

| Name                                                                                                               | Source                     | Version |
|--------------------------------------------------------------------------------------------------------------------|----------------------------|---------|
| <a name="module_cloudwatch_log_group_kms"></a> [cloudwatch\_log\_group\_kms](#module\_cloudwatch\_log\_group\_kms) | oozou/kms-key/aws          | 1.0.0   |
| <a name="module_secret_kms_key"></a> [secret\_kms\_key](#module\_secret\_kms\_key)                                 | oozou/kms-key/aws          | 1.0.0   |
| <a name="module_step_alarm"></a> [step\_alarm](#module\_step\_alarm)                                               | oozou/cloudwatch-alarm/aws | 1.0.0   |

## Resources

| Name                                                                                                                                                            | Type        |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------|
| [aws_appautoscaling_policy.step_scaling_policies](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy)            | resource    |
| [aws_appautoscaling_policy.target_tracking_scaling_policies](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource    |
| [aws_appautoscaling_target.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target)                             | resource    |
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group)                               | resource    |
| [aws_ecs_service.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service)                                                 | resource    |
| [aws_ecs_task_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition)                                 | resource    |
| [aws_iam_role.task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)                                        | resource    |
| [aws_iam_role.task_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)                                                  | resource    |
| [aws_iam_role_policy.task_execution_role_access_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy)            | resource    |
| [aws_iam_role_policy_attachment.task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment)    | resource    |
| [aws_iam_role_policy_attachment.task_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment)              | resource    |
| [aws_lb_listener_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule)                                       | resource    |
| [aws_lb_target_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group)                                         | resource    |
| [aws_secretsmanager_secret.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret)                             | resource    |
| [aws_secretsmanager_secret_version.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version)             | resource    |
| [aws_service_discovery_service.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_service)                  | resource    |
| [random_string.service_secret_random_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string)                             | resource    |
| [aws_caller_identity.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity)                                      | data source |
| [aws_iam_policy_document.cloudwatch_log_group_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)   | data source |
| [aws_iam_policy_document.task_assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)           | data source |
| [aws_iam_policy_document.task_execution_assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region)                                                        | data source |

## Inputs

| Name                                                                                                                                                                                     | Description                                                                                                                                                                                           | Type                                                                         | Default                                                                                                    | Required |
|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------|:--------:|
| <a name="input_additional_ecs_task_execution_role_policy_arns"></a> [additional\_ecs\_task\_execution\_role\_policy\_arns](#input\_additional\_ecs\_task\_execution\_role\_policy\_arns) | List of policies ARNs to attach to the ECS Task Role. eg: { rds\_arn = module.postgres\_db.rds\_policy\_arn }                                                                                         | `list(string)`                                                               | `[]`                                                                                                       |    no    |
| <a name="input_additional_ecs_task_role_policy_arns"></a> [additional\_ecs\_task\_role\_policy\_arns](#input\_additional\_ecs\_task\_role\_policy\_arns)                                 | List of policies ARNs to attach to the ECS Task Role. eg: { rds\_arn = module.postgres\_db.rds\_policy\_arn }                                                                                         | `list(string)`                                                               | `[]`                                                                                                       |    no    |
| <a name="input_alb_host_header"></a> [alb\_host\_header](#input\_alb\_host\_header)                                                                                                      | Mention host header for api endpoint                                                                                                                                                                  | `string`                                                                     | `null`                                                                                                     |    no    |
| <a name="input_alb_listener_arn"></a> [alb\_listener\_arn](#input\_alb\_listener\_arn)                                                                                                   | The ALB listener to attach to                                                                                                                                                                         | `string`                                                                     | `""`                                                                                                       |    no    |
| <a name="input_alb_paths"></a> [alb\_paths](#input\_alb\_paths)                                                                                                                          | Mention list Path For ALB routing eg: ["/"] or ["/route1"]                                                                                                                                            | `list(string)`                                                               | `[]`                                                                                                       |    no    |
| <a name="input_alb_priority"></a> [alb\_priority](#input\_alb\_priority)                                                                                                                 | Priority of ALB rule https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-listeners.html#listener-rules                                                                  | `string`                                                                     | `"100"`                                                                                                    |    no    |
| <a name="input_application_subnet_ids"></a> [application\_subnet\_ids](#input\_application\_subnet\_ids)                                                                                 | Subnet IDs to deploy into                                                                                                                                                                             | `list(string)`                                                               | n/a                                                                                                        |   yes    |
| <a name="input_capacity_provider_strategy"></a> [capacity\_provider\_strategy](#input\_capacity\_provider\_strategy)                                                                     | Capacity provider strategies to use for the service EC2 Autoscaling group                                                                                                                             | `map(any)`                                                                   | `null`                                                                                                     |    no    |
| <a name="input_cloudwatch_log_group_kms_key_arn"></a> [cloudwatch\_log\_group\_kms\_key\_arn](#input\_cloudwatch\_log\_group\_kms\_key\_arn)                                             | The ARN for the KMS encryption key.                                                                                                                                                                   | `string`                                                                     | `null`                                                                                                     |    no    |
| <a name="input_cloudwatch_log_retention_in_days"></a> [cloudwatch\_log\_retention\_in\_days](#input\_cloudwatch\_log\_retention\_in\_days)                                               | Retention day for cloudwatch log group                                                                                                                                                                | `number`                                                                     | `90`                                                                                                       |    no    |
| <a name="input_container"></a> [container](#input\_container)                                                                                                                            | The container(s) that would be rendered in task definition; see example for completion                                                                                                                | `any`                                                                        | `{}`                                                                                                       |    no    |
| <a name="input_custom_header_token"></a> [custom\_header\_token](#input\_custom\_header\_token)                                                                                          | [Required] Specify secret value for custom header                                                                                                                                                     | `string`                                                                     | `""`                                                                                                       |    no    |
| <a name="input_deployment_circuit_breaker"></a> [deployment\_circuit\_breaker](#input\_deployment\_circuit\_breaker)                                                                     | Configuration block for deployment circuit breaker                                                                                                                                                    | <pre>object({<br>    enable   = bool<br>    rollback = bool<br>  })</pre>    | <pre>{<br>  "enable": true,<br>  "rollback": true<br>}</pre>                                               |    no    |
| <a name="input_ecs_cluster_name"></a> [ecs\_cluster\_name](#input\_ecs\_cluster\_name)                                                                                                   | ECS Cluster name to deploy in                                                                                                                                                                         | `string`                                                                     | n/a                                                                                                        |   yes    |
| <a name="input_efs_volumes"></a> [efs\_volumes](#input\_efs\_volumes)                                                                                                                    | Task EFS volume definitions as list of configuration objects. You cannot define both Docker volumes and EFS volumes on the same task definition.                                                      | `list(any)`                                                                  | `[]`                                                                                                       |    no    |
| <a name="input_environment"></a> [environment](#input\_environment)                                                                                                                      | (Optional) Environment as a part of format("%s-%s-%s-cf", var.prefix, var.environment, var.name); ex. xxx-prod-xxx-cf                                                                                 | `string`                                                                     | `""`                                                                                                       |    no    |
| <a name="input_environment_variables"></a> [environment\_variables](#input\_environment\_variables)                                                                                      | Map of environment varaibles ex. { RDS\_ENDPOINT = "admin@rds@123"}                                                                                                                                   | `map(map(any))`                                                              | `{}`                                                                                                       |    no    |
| <a name="input_exists_task_execution_role_arn"></a> [exists\_task\_execution\_role\_arn](#input\_exists\_task\_execution\_role\_arn)                                                     | The existing arn of task exec role                                                                                                                                                                    | `string`                                                                     | `""`                                                                                                       |    no    |
| <a name="input_exists_task_role_arn"></a> [exists\_task\_role\_arn](#input\_exists\_task\_role\_arn)                                                                                     | The existing arn of task role                                                                                                                                                                         | `string`                                                                     | `""`                                                                                                       |    no    |
| <a name="input_health_check"></a> [health\_check](#input\_health\_check)                                                                                                                 | Health Check Config for the service                                                                                                                                                                   | `map(string)`                                                                | `{}`                                                                                                       |    no    |
| <a name="input_is_application_scratch_volume_enabled"></a> [is\_application\_scratch\_volume\_enabled](#input\_is\_application\_scratch\_volume\_enabled)                                | To enabled the temporary storage for the service                                                                                                                                                      | `bool`                                                                       | `false`                                                                                                    |    no    |
| <a name="input_is_create_cloudwatch_log_group"></a> [is\_create\_cloudwatch\_log\_group](#input\_is\_create\_cloudwatch\_log\_group)                                                     | Whether to create cloudwatch log group or not                                                                                                                                                         | `bool`                                                                       | `true`                                                                                                     |    no    |
| <a name="input_is_create_default_kms"></a> [is\_create\_default\_kms](#input\_is\_create\_default\_kms)                                                                                  | Whether to create cloudwatch log group kms or not                                                                                                                                                     | `bool`                                                                       | `true`                                                                                                     |    no    |
| <a name="input_is_create_iam_role"></a> [is\_create\_iam\_role](#input\_is\_create\_iam\_role)                                                                                           | Create the built in IAM role for task role and task exec role                                                                                                                                         | `bool`                                                                       | `true`                                                                                                     |    no    |
| <a name="input_is_enable_execute_command"></a> [is\_enable\_execute\_command](#input\_is\_enable\_execute\_command)                                                                      | Specifies whether to enable Amazon ECS Exec for the tasks within the service.                                                                                                                         | `bool`                                                                       | `false`                                                                                                    |    no    |
| <a name="input_name"></a> [name](#input\_name)                                                                                                                                           | (Optional) Name as a part of format("%s-%s-%s-cf", var.prefix, var.environment, var.name); ex. xxx-xxx-cms-cf                                                                                         | `string`                                                                     | `""`                                                                                                       |    no    |
| <a name="input_name_override"></a> [name\_override](#input\_name\_override)                                                                                                              | (Optional) Full name to override usage from format("%s-%s-%s-cf", var.prefix, var.environment, var.name)                                                                                              | `string`                                                                     | `""`                                                                                                       |    no    |
| <a name="input_ordered_placement_strategy"></a> [ordered\_placement\_strategy](#input\_ordered\_placement\_strategy)                                                                     | Service level strategy rules that are taken into consideration during task placement                                                                                                                  | <pre>set(object({<br>    type  = string<br>    field = string<br>  }))</pre> | <pre>[<br>  {<br>    "field": "attribute:ecs.availability-zone",<br>    "type": "spread"<br>  }<br>]</pre> |    no    |
| <a name="input_prefix"></a> [prefix](#input\_prefix)                                                                                                                                     | (Optional) Prefix as a part of format("%s-%s-%s-cf", var.prefix, var.environment, var.name); ex. oozou-xxx-xxx-cf                                                                                     | `string`                                                                     | `""`                                                                                                       |    no    |
| <a name="input_propagate_tags"></a> [propagate\_tags](#input\_propagate\_tags)                                                                                                           | (Optional) Specifies whether to propagate the tags from the task definition or the service to the tasks. The valid values are SERVICE and TASK\_DEFINITION.                                           | `string`                                                                     | `"TASK_DEFINITION"`                                                                                        |    no    |
| <a name="input_secret_variables"></a> [secret\_variables](#input\_secret\_variables)                                                                                                     | Map of secret name(as reflected in Secrets Manager) and secret JSON string associated                                                                                                                 | `map(map(any))`                                                              | `{}`                                                                                                       |    no    |
| <a name="input_security_groups"></a> [security\_groups](#input\_security\_groups)                                                                                                        | Security groups to apply to service                                                                                                                                                                   | `list(string)`                                                               | n/a                                                                                                        |   yes    |
| <a name="input_service_count"></a> [service\_count](#input\_service\_count)                                                                                                              | Number of containers to deploy                                                                                                                                                                        | `number`                                                                     | `1`                                                                                                        |    no    |
| <a name="input_service_discovery_namespace"></a> [service\_discovery\_namespace](#input\_service\_discovery\_namespace)                                                                  | DNS Namespace to deploy to                                                                                                                                                                            | `string`                                                                     | n/a                                                                                                        |   yes    |
| <a name="input_step_scaling_configuration"></a> [step\_scaling\_configuration](#input\_step\_scaling\_configuration)                                                                     | (optional) Define step scaling behaviour, example in README                                                                                                                                           | `any`                                                                        | `{}`                                                                                                       |    no    |
| <a name="input_tags"></a> [tags](#input\_tags)                                                                                                                                           | Custom tags which can be passed on to the AWS resources. They should be key value pairs having distinct keys                                                                                          | `map(any)`                                                                   | `{}`                                                                                                       |    no    |
| <a name="input_target_group_deregistration_delay"></a> [target\_group\_deregistration\_delay](#input\_target\_group\_deregistration\_delay)                                              | (Optional) Amount time for Elastic Load Balancing to wait before changing the state of a deregistering target from draining to unused. The range is 0-3600 seconds. The default value is 300 seconds. | `number`                                                                     | `300`                                                                                                      |    no    |
| <a name="input_target_tracking_configuration"></a> [target\_tracking\_configuration](#input\_target\_tracking\_configuration)                                                            | (optional) Define traget tracking behaviour, example in README                                                                                                                                        | `any`                                                                        | `{}`                                                                                                       |    no    |
| <a name="input_task_cpu"></a> [task\_cpu](#input\_task\_cpu)                                                                                                                             | (Require): cpu for task level                                                                                                                                                                         | `number`                                                                     | n/a                                                                                                        |   yes    |
| <a name="input_task_memory"></a> [task\_memory](#input\_task\_memory)                                                                                                                    | (Require): memory for task level                                                                                                                                                                      | `number`                                                                     | n/a                                                                                                        |   yes    |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id)                                                                                                                                   | VPC id where security group is created                                                                                                                                                                | `string`                                                                     | `""`                                                                                                       |    no    |

## Outputs

| Name                                                                                                                  | Description                                 |
|-----------------------------------------------------------------------------------------------------------------------|---------------------------------------------|
| <a name="output_cloudwatch_log_group_arn"></a> [cloudwatch\_log\_group\_arn](#output\_cloudwatch\_log\_group\_arn)    | The name of the log group                   |
| <a name="output_cloudwatch_log_group_name"></a> [cloudwatch\_log\_group\_name](#output\_cloudwatch\_log\_group\_name) | The name of the log group                   |
| <a name="output_secret_arns"></a> [secret\_arns](#output\_secret\_arns)                                               | List of ARNs of the SecretsManager secrets  |
| <a name="output_target_group_arn"></a> [target\_group\_arn](#output\_target\_group\_arn)                              | id - ARN of the Target Group (matches arn). |
| <a name="output_target_group_id"></a> [target\_group\_id](#output\_target\_group\_id)                                 | id - ARN of the Target Group (matches arn). |
| <a name="output_task_execution_role_arn"></a> [task\_execution\_role\_arn](#output\_task\_execution\_role\_arn)       | ECS Task execution role ARN                 |
| <a name="output_task_execution_role_id"></a> [task\_execution\_role\_id](#output\_task\_execution\_role\_id)          | ECS Task execution role ID                  |
| <a name="output_task_role_arn"></a> [task\_role\_arn](#output\_task\_role\_arn)                                       | ECS Task role ARN                           |
<!-- END_TF_DOCS -->
