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

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_service_api"></a> [service\_api](#module\_service\_api) | ../.. | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_generics_info"></a> [generics\_info](#input\_generics\_info) | Generic infomation | <pre>object({<br>    region      = string<br>    prefix      = string<br>    environment = string<br>    name        = string<br>    custom_tags = map(any)<br>  })</pre> | n/a | yes |
| <a name="input_service_info"></a> [service\_info](#input\_service\_info) | is\_attach\_service\_with\_lb >> Attach the container to the public ALB? (true/false)<br>  service\_alb\_host\_header   >> Mention host header for api endpoint<br>  service\_info              >> The configuration of service<br>  health\_check              >> Health Check Config for the service | <pre>map(object({<br>    is_attach_service_with_lb = bool<br>    service_alb_host_header   = string<br>    alb_paths                 = list(string)<br>    alb_priority              = string<br>    service_info = object({<br>      cpu_allocation = number<br>      mem_allocation = number<br>      containers_num = number<br>      port           = number<br>      image          = string<br>    })<br>    health_check = object({<br>      interval            = number<br>      path                = string<br>      timeout             = number<br>      healthy_threshold   = number<br>      unhealthy_threshold = number<br>      matcher             = string<br>    })<br>  }))</pre> | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | A list of subnet IDs to launch resources in | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID to deploy | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->