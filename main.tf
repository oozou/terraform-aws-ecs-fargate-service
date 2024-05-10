/* -------------------------------------------------------------------------- */
/*                                  Task Role                                 */
/* -------------------------------------------------------------------------- */
data "aws_iam_policy_document" "task_assume_role_policy" {
  count = var.is_create_iam_role ? 1 : 0

  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_role" {
  count = var.is_create_iam_role ? 1 : 0

  name               = format("%s-ecs-task-role", local.name)
  assume_role_policy = data.aws_iam_policy_document.task_assume_role_policy[0].json

  tags = merge(local.tags, { "Name" = format("%s-ecs-task-role", local.name) })
}

resource "aws_iam_role_policy_attachment" "task_role" {
  count = var.is_create_iam_role ? length(var.additional_ecs_task_role_policy_arns) : 0

  role       = local.task_role_name
  policy_arn = var.additional_ecs_task_role_policy_arns[count.index]
}

/* -------------------------------------------------------------------------- */
/*                               Task Exec Role                               */
/* -------------------------------------------------------------------------- */
data "aws_iam_policy_document" "task_execution_assume_role_policy" {
  count = var.is_create_iam_role ? 1 : 0

  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_execution_role" {
  count = var.is_create_iam_role ? 1 : 0

  name               = format("%s-ecs-task-execution-role", local.name)
  assume_role_policy = data.aws_iam_policy_document.task_execution_assume_role_policy[0].json

  tags = merge(local.tags, { "Name" = format("%s-ecs-task-execution-role", local.name) })
}

resource "aws_iam_role_policy_attachment" "task_execution_role" {
  for_each = var.is_create_iam_role ? local.ecs_task_execution_role_policy_arns : []

  role       = local.task_execution_role_name
  policy_arn = each.value
}

/* -------------------------------------------------------------------------- */
/*                                 CloudWatch                                 */
/* -------------------------------------------------------------------------- */
data "aws_iam_policy_document" "cloudwatch_log_group_kms_policy" {
  statement {
    sid = "AllowCloudWatchToDoCryptography"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = tolist([format("logs.%s.amazonaws.com", data.aws_region.this.name)])
    }

    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = [format("arn:aws:logs:%s:%s:log-group:%s", data.aws_region.this.name, data.aws_caller_identity.this.account_id, local.log_group_name)]
    }
  }
}

module "cloudwatch_log_group_kms" {
  count   = var.is_create_cloudwatch_log_group && var.is_create_default_kms && var.cloudwatch_log_group_kms_key_arn == null ? 1 : 0
  source  = "oozou/kms-key/aws"
  version = "1.0.0"

  prefix               = var.prefix
  environment          = var.environment
  name                 = format("%s-log-group", var.name)
  key_type             = "service"
  append_random_suffix = true
  description          = format("Secure Secrets Manager's service secrets for service %s", local.name)
  additional_policies  = [data.aws_iam_policy_document.cloudwatch_log_group_kms_policy.json]

  tags = merge(local.tags, { "Name" : format("%s-log-group", local.name) })
}

resource "aws_cloudwatch_log_group" "this" {
  count = var.is_create_cloudwatch_log_group ? 1 : 0

  name              = local.log_group_name
  retention_in_days = var.cloudwatch_log_retention_in_days
  kms_key_id        = local.cloudwatch_log_group_kms_key_arn

  tags = merge(local.tags, { "Name" = local.log_group_name })
}

/* -------------------------------------------------------------------------- */
/*                                Load Balancer                               */
/* -------------------------------------------------------------------------- */
resource "aws_lb_target_group" "this" {
  count = local.is_create_target_group ? 1 : 0

  name = format("%s-tg", substr(local.container_target_group_object.name, 0, min(29, length(local.container_target_group_object.name))))

  port                 = lookup(local.container_target_group_object, "port_mappings", null)[0].container_port
  protocol             = lookup(local.container_target_group_object, "port_mappings", null)[0].container_port == 443 ? "HTTPS" : "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  deregistration_delay = var.target_group_deregistration_delay

  health_check {
    interval            = lookup(var.health_check, "interval", null)
    path                = lookup(var.health_check, "path", null)
    timeout             = lookup(var.health_check, "timeout", null)
    healthy_threshold   = lookup(var.health_check, "healthy_threshold", null)
    unhealthy_threshold = lookup(var.health_check, "unhealthy_threshold", null)
    matcher             = lookup(var.health_check, "matcher", null)
  }

  tags = merge(local.tags, { "Name" = format("%s-tg", substr(local.container_target_group_object.name, 0, min(29, length(local.container_target_group_object.name)))) })
}
/* ------------------------------ Listener Rule ----------------------------- */
resource "aws_lb_listener_rule" "this" {
  count = local.is_create_target_group ? 1 : 0

  listener_arn = var.alb_listener_arn
  priority     = var.alb_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[0].arn
  }

  condition {
    path_pattern {
      values = var.alb_paths == [] ? ["*"] : var.alb_paths
    }
  }

  dynamic "condition" {
    for_each = var.alb_host_header == null ? [] : [true]
    content {
      host_header {
        values = [var.alb_host_header]
      }
    }
  }

  dynamic "condition" {
    for_each = var.custom_header_token == "" ? [] : [true]
    content {
      http_header {
        http_header_name = "custom-header-token" # Match value within cloudfront module
        values           = [var.custom_header_token]
      }
    }
  }

  tags = local.tags
}
/* -------------------------------------------------------------------------- */
/*                                   Secret                                   */
/* -------------------------------------------------------------------------- */
module "secret_kms_key" {
  source  = "oozou/kms-key/aws"
  version = "1.0.0"

  prefix               = var.prefix
  environment          = var.environment
  name                 = format("%s-ecs", var.name)
  key_type             = "service"
  append_random_suffix = true
  description          = format("Secure Secrets Manager's service secrets for service %s", local.name)

  service_key_info = {
    aws_service_names  = tolist([format("secretsmanager.%s.amazonaws.com", data.aws_region.this.name)])
    caller_account_ids = tolist([data.aws_caller_identity.this.account_id])
  }

  tags = merge(local.tags, { "Name" : format("%s-ecs", local.name) })
}

resource "random_string" "service_secret_random_suffix" {
  for_each = var.container

  length  = 5
  special = false
}

/* -------------------------------------------------------------------------- */
/*                                   Secret                                   */
/* -------------------------------------------------------------------------- */
resource "aws_secretsmanager_secret" "this" {
  for_each = var.container

  name        = "${each.value.name}/${random_string.service_secret_random_suffix[each.key].result}"
  description = "Secret for service ${local.name}"
  kms_key_id  = module.secret_kms_key.key_arn

  tags = merge({ Name = "${each.value.name}/${random_string.service_secret_random_suffix[each.key].result}" }, local.tags)
}

resource "aws_secretsmanager_secret_version" "this" {
  for_each = var.container

  secret_id     = aws_secretsmanager_secret.this[each.key].id
  secret_string = jsonencode(try(var.secret_variables[each.key], {}))
}

# We add a policy to the ECS Task Execution role so that ECS can pull secrets from SecretsManager and
# inject them as environment variables in the service
resource "aws_iam_role_policy" "task_execution_role_access_secret" {
  # count    = var.is_create_iam_role && length(var.secret_variables) > 0 ? 1 : 0
  for_each = var.container

  name = "${each.value.name}-ecs-task-execution-secrets"
  role = local.task_execution_role_id

  policy = <<EOF
{
    "Statement": [
      {
        "Effect": "Allow",
        "Action": ["secretsmanager:GetSecretValue"],
        "Resource": ${jsonencode(format("%s/*", split("/", aws_secretsmanager_secret.this[each.key].arn)[0]))}
      }
    ]
}
EOF
}

/* -------------------------------------------------------------------------- */
/*                             ECS Task Definition                            */
/* -------------------------------------------------------------------------- */
resource "aws_ecs_task_definition" "this" {
  family                   = local.name
  network_mode             = "awsvpc"
  requires_compatibilities = var.capacity_provider_strategy == null ? ["FARGATE"] : ["EC2"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = local.task_execution_role_arn
  task_role_arn            = local.task_role_arn

  container_definitions = jsonencode(local.container_task_definitions)

  dynamic "volume" {
    for_each = local.volumes
    content {
      host_path = lookup(volume.value, "host_path", null)
      name      = volume.value.name

      dynamic "efs_volume_configuration" {
        for_each = lookup(volume.value, "efs_volume_configuration", [])
        content {
          file_system_id          = lookup(efs_volume_configuration.value, "file_system_id", null)
          root_directory          = lookup(efs_volume_configuration.value, "root_directory", null)
          transit_encryption      = lookup(efs_volume_configuration.value, "transit_encryption", null)
          transit_encryption_port = lookup(efs_volume_configuration.value, "transit_encryption_port", null)
          dynamic "authorization_config" {
            for_each = lookup(efs_volume_configuration.value, "authorization_config", [])
            content {
              access_point_id = lookup(authorization_config.value, "access_point_id", null)
              iam             = lookup(authorization_config.value, "iam", null)
            }
          }
        }
      }
    }
  }

  dynamic "volume" {
    for_each = var.is_application_scratch_volume_enabled ? [true] : []
    content {
      name = "application_scratch"
    }
  }

  tags = merge(local.tags, { "Name" = local.name })
}

/* -------------------------------------------------------------------------- */
/*                                 ECS Service                                */
/* -------------------------------------------------------------------------- */
resource "aws_service_discovery_service" "service" {
  name = local.name

  dns_config {
    namespace_id = var.service_discovery_namespace

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_service" "this" {
  name                    = format("%s", local.name)
  cluster                 = local.ecs_cluster_arn
  task_definition         = aws_ecs_task_definition.this.arn
  desired_count           = var.service_count
  enable_execute_command  = var.is_enable_execute_command
  enable_ecs_managed_tags = true
  launch_type             = var.capacity_provider_strategy == null ? "FARGATE" : null
  propagate_tags          = var.propagate_tags

  network_configuration {
    security_groups = var.security_groups
    subnets         = var.application_subnet_ids
  }

  dynamic "ordered_placement_strategy" {
    for_each = var.capacity_provider_strategy == null ? [] : var.ordered_placement_strategy
    content {
      type  = ordered_placement_strategy.value.type
      field = ordered_placement_strategy.value.field
    }
  }

  service_registries {
    registry_arn   = aws_service_discovery_service.service.arn
    container_name = local.name
  }

  dynamic "capacity_provider_strategy" {
    for_each = var.capacity_provider_strategy == null ? [] : [true]
    content {
      base              = var.capacity_provider_strategy.base
      capacity_provider = var.capacity_provider_strategy.capacity_provider
      weight            = var.capacity_provider_strategy.weight
    }
  }

  deployment_circuit_breaker {
    enable   = var.deployment_circuit_breaker.enable
    rollback = var.deployment_circuit_breaker.rollback
  }

  dynamic "load_balancer" {
    for_each = local.is_create_target_group ? [true] : []

    content {
      target_group_arn = aws_lb_target_group.this[0].arn
      container_name   = local.name
      container_port   = local.container_target_group_object.port_mappings[0].container_port
    }
  }

  lifecycle {
    ignore_changes = [
      task_definition,
      desired_count
    ]
  }

  tags = merge(local.tags, { Name = format("%s", local.name) })
}

/* -------------------------------------------------------------------------- */
/*                             Auto Scaling Target                            */
/* -------------------------------------------------------------------------- */
resource "aws_appautoscaling_target" "this" {
  count = local.is_created_aws_appautoscaling_target ? 1 : 0

  max_capacity = try(
    var.target_tracking_configuration.capacity.max_capacity,
    var.step_scaling_configuration.capacity.max_capacity
  )
  min_capacity = try(
    var.target_tracking_configuration.capacity.min_capacity,
    var.step_scaling_configuration.capacity.min_capacity
  )
  resource_id        = format("service/%s/%s", var.ecs_cluster_name, local.name)
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  # lifecycle {
  #   ignore_changes = var.ignore_update_scaling_policy ? dynamic(["max_capacity", "min_capacity", "resource_id", "scalable_dimension", "service_namespace"]) : []
  # }

  lifecycle {
    ignore_changes = local.update_scaling_policy
  }
}

/* -------------------------------------------------------------------------- */
/*                             Auto Scaling Policy                            */
/* -------------------------------------------------------------------------- */
resource "aws_appautoscaling_policy" "target_tracking_scaling_policies" {
  count = local.is_target_tracking_scaling ? 1 : 0

  depends_on = [aws_appautoscaling_target.this[0]]

  name               = format("%s-%s-scaling-policy", local.name, var.target_tracking_configuration["name"])
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace

  policy_type = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    target_value       = lookup(var.target_tracking_configuration["scaling_behaviors"], "target_value", null)
    scale_in_cooldown  = lookup(var.target_tracking_configuration["scaling_behaviors"], "scale_in_cooldown", 180)
    scale_out_cooldown = lookup(var.target_tracking_configuration["scaling_behaviors"], "scale_out_cooldown", 60)

    dynamic "predefined_metric_specification" {
      for_each = local.is_contain_predefined_metric ? [true] : []
      iterator = _null
      content {
        predefined_metric_type = lookup(var.target_tracking_configuration["scaling_behaviors"], "predefined_metric_type", null)
      }
    }

    dynamic "customized_metric_specification" {
      for_each = !local.is_contain_predefined_metric ? [true] : []
      iterator = _null

      content {
        dynamic "metrics" {
          for_each = { for k, v in lookup(var.target_tracking_configuration["scaling_behaviors"], "custom_metrics", {}) : k => v if lookup(v, "expression", null) == null }
          iterator = custom_metric

          content {
            id          = lookup(custom_metric.value, "id", null)
            label       = lookup(custom_metric.value, "label", replace("_", "-", custom_metric.key))
            expression  = lookup(custom_metric.value, "expression", null)
            return_data = lookup(custom_metric.value, "return_data", true)
            metric_stat {
              stat = lookup(lookup(custom_metric.value, "metric_stat", {}), "stat", "")
              metric {
                metric_name = lookup(lookup(custom_metric.value, "metric_stat", {}), "metric_name", null)
                namespace   = lookup(lookup(custom_metric.value, "metric_stat", {}), "namespace", null)
                dynamic "dimensions" {
                  for_each = lookup(lookup(custom_metric.value, "metric_stat", {}), "dimensions", [])
                  iterator = dimension

                  content {
                    name  = lookup(dimension.value, "name", null)
                    value = lookup(dimension.value, "value", null)
                  }
                }
              }
            }
          }
        }

        dynamic "metrics" {
          for_each = { for k, v in lookup(var.target_tracking_configuration["scaling_behaviors"], "custom_metrics", {}) : k => v if lookup(v, "expression", null) != null }
          iterator = custom_metric

          content {
            id          = lookup(custom_metric.value, "id", null)
            label       = lookup(custom_metric.value, "label", replace("_", "-", custom_metric.key))
            expression  = lookup(custom_metric.value, "expression", null)
            return_data = lookup(custom_metric.value, "return_data", true)
          }
        }
      }
    }
  }
}

resource "aws_appautoscaling_policy" "step_scaling_policies" {
  for_each = try(var.step_scaling_configuration.policy_type, null) == "StepScaling" ? var.step_scaling_configuration["scaling_behaviors"] : {}

  depends_on = [aws_appautoscaling_target.this[0]]

  name               = format("%s-%s-scaling-policy", local.name, replace(each.key, "_", "-"))
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace

  policy_type = "StepScaling"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = lookup(each.value, "cooldown", null)
    metric_aggregation_type = lookup(each.value, "statistic", null)

    dynamic "step_adjustment" {
      for_each = lookup(each.value, "step_adjustment", [])
      iterator = step_adjustment

      content {
        metric_interval_lower_bound = lookup(step_adjustment.value, "metric_interval_lower_bound", null)
        metric_interval_upper_bound = lookup(step_adjustment.value, "metric_interval_upper_bound", null)
        scaling_adjustment          = lookup(step_adjustment.value, "scaling_adjustment", null)
      }
    }
  }
}

module "step_alarm" {
  source  = "oozou/cloudwatch-alarm/aws"
  version = "1.0.0"

  for_each = try(var.step_scaling_configuration.policy_type, null) == "StepScaling" ? var.step_scaling_configuration["scaling_behaviors"] : {}

  depends_on = [aws_appautoscaling_target.this[0]]

  prefix      = var.prefix
  environment = var.environment
  name        = format("%s-scaling-policy", replace(each.key, "_", "-"))

  alarm_description = format(
    "%s's %s %s %s in period %ss with %s datapoint",
    lookup(each.value, "metric_name", "custom-metric"),
    lookup(each.value, "statistic", "null"),
    lookup(each.value, "comparison_operator", "null"),
    lookup(each.value, "threshold", "null"),
    lookup(each.value, "period", "null"),
    lookup(each.value, "evaluation_periods", "null")
  )

  comparison_operator = local.comparison_operators[lookup(each.value, "comparison_operator", null)]
  evaluation_periods  = lookup(each.value, "evaluation_periods", null)
  metric_name         = lookup(each.value, "metric_name", null)
  metric_query        = lookup(each.value, "metric_query", [])
  namespace           = lookup(each.value, "namespace", null)
  period              = lookup(each.value, "period", null)
  statistic           = lookup(each.value, "metric_query", null) == null ? lookup(each.value, "statistic", null) : null
  threshold           = lookup(each.value, "threshold", null)

  dimensions = lookup(each.value, "metric_query", null) == null ? {
    ClusterName = var.ecs_cluster_name
    ServiceName = local.name
  } : null

  alarm_actions = concat(
    [aws_appautoscaling_policy.step_scaling_policies[each.key].arn],
    lookup(each.value, "alarm_actions", lookup(var.step_scaling_configuration, "default_alarm_actions", []))
  )

  tags = local.tags
}
