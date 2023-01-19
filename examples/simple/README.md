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

No requirements.

## Providers

| Name                                              | Version |
|---------------------------------------------------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 4.50.0  |

## Modules

| Name                                                                                | Source                        | Version |
|-------------------------------------------------------------------------------------|-------------------------------|---------|
| <a name="module_fargate_cluster"></a> [fargate\_cluster](#module\_fargate\_cluster) | oozou/ecs-fargate-cluster/aws | 1.0.7   |
| <a name="module_service_api"></a> [service\_api](#module\_service\_api)             | ../..                         | n/a     |
| <a name="module_vpc"></a> [vpc](#module\_vpc)                                       | oozou/vpc/aws                 | 1.2.4   |

## Resources

| Name                                                                                                                       | Type        |
|----------------------------------------------------------------------------------------------------------------------------|-------------|
| [aws_caller_identity.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region)                   | data source |

## Inputs

| Name                                                                  | Description                                                                                                   | Type          | Default | Required |
|-----------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------|---------------|---------|:--------:|
| <a name="input_custom_tags"></a> [custom\_tags](#input\_custom\_tags) | Custom tags which can be passed on to the AWS resources. They should be key value pairs having distinct keys. | `map(string)` | `{}`    |    no    |
| <a name="input_environment"></a> [environment](#input\_environment)   | [Required] Name prefix used for resource naming in this component                                             | `string`      | n/a     |   yes    |
| <a name="input_name"></a> [name](#input\_name)                        | [Required] Name of Platfrom or application                                                                    | `string`      | n/a     |   yes    |
| <a name="input_prefix"></a> [prefix](#input\_prefix)                  | [Required] Name prefix used for resource naming in this component                                             | `string`      | n/a     |   yes    |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
