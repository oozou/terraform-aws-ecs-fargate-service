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

  name               = format("%s-ecs-task-role", local.service_name)
  assume_role_policy = data.aws_iam_policy_document.task_assume_role_policy[0].json

  tags = merge(local.tags, { "Name" = format("%s-ecs-task-role", local.service_name) })
}

resource "aws_iam_role_policy_attachment" "task_role" {
  count = var.is_create_iam_role ? length(var.additional_ecs_task_role_policy_arns) : 0

  role       = local.task_role_name
  policy_arn = var.additional_ecs_task_role_policy_arns[count.index]
}
/* -------------------------------- Validator ------------------------------- */
data "aws_iam_role" "get_ecs_task_role" {
  count = !var.is_create_iam_role ? 1 : 0

  name = local.task_role_name
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

  name               = format("%s-ecs-task-execution-role", local.service_name)
  assume_role_policy = data.aws_iam_policy_document.task_execution_assume_role_policy[0].json

  tags = merge(local.tags, { "Name" = format("%s-ecs-task-execution-role", local.service_name) })
}

resource "aws_iam_role_policy_attachment" "task_execution_role" {
  for_each = var.is_create_iam_role ? local.ecs_task_execution_role_policy_arns : []

  role       = local.task_execution_role_name
  policy_arn = each.value
}
/* -------------------------------- Validator ------------------------------- */
data "aws_iam_role" "get_ecs_task_execution_role" {
  count = !var.is_create_iam_role ? 1 : 0

  name = local.task_execution_role_name
}

/* -------------------------------------------------------------------------- */
/*                                 CloudWatch                                 */
/* -------------------------------------------------------------------------- */
resource "aws_cloudwatch_log_group" "this" {
  count = var.is_create_cloudwatch_log_group ? 1 : 0

  name              = local.log_group_name
  retention_in_days = var.cloudwatch_log_retention_in_days
  kms_key_id        = var.cloudwatch_log_kms_key_id

  tags = merge(local.tags, { "Name" = local.log_group_name })
}

/* -------------------------------------------------------------------------- */
/*                                Load Balancer                               */
/* -------------------------------------------------------------------------- */
/* ----------------------------- LB Target Group ---------------------------- */
resource "aws_lb_target_group" "this" {
  count = var.is_attach_service_with_lb ? 1 : 0

  name = format("%s-tg", substr("${local.service_name}", 0, min(29, length(local.service_name))))

  port                 = var.service_info.port
  protocol             = var.service_info.port == 443 ? "HTTPS" : "HTTP"
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

  tags = merge(local.tags, { "Name" = format("%s-tg", local.service_name) })
}
/* ------------------------------ Listener Rule ----------------------------- */
resource "aws_lb_listener_rule" "this" {
  count = var.is_attach_service_with_lb ? 1 : 0

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

  name                 = format("%s-service-secrets", local.service_name)
  prefix               = var.prefix
  environment          = var.environment
  key_type             = "service"
  append_random_suffix = true
  description          = format("Secure Secrets Manager's service secrets for service %s", local.service_name)

  service_key_info = {
    aws_service_names  = tolist([format("secretsmanager.%s.amazonaws.com", data.aws_region.current.name)])
    caller_account_ids = tolist([data.aws_caller_identity.current.account_id])
  }

  tags = merge(local.tags, { "Name" : format("%s-service-secrets", local.service_name) })
}

# Append random string to SM Secret names because once we tear down the infra, the secret does not actually
# get deleted right away, which means that if we then try to recreate the infra, it'll fail as the
# secret name already exists.
resource "random_string" "service_secret_random_suffix" {
  length  = 6
  special = false
}

resource "aws_secretsmanager_secret" "service_secrets" {
  for_each = var.secrets

  name        = "${local.service_name}/${lower(each.key)}-${random_string.service_secret_random_suffix.result}"
  description = "Secret 'secret_${lower(each.key)}' for service ${local.service_name}"
  kms_key_id  = module.secret_kms_key.key_arn

  tags = merge(local.tags, { Name = "${local.service_name}/${each.key}" })
}

resource "aws_secretsmanager_secret_version" "service_secrets" {
  for_each = var.secrets

  secret_id     = aws_secretsmanager_secret.service_secrets[each.key].id
  secret_string = each.value
}


# /* -------------------------------------------------------------------------- */
# /*                                 JSON SECRET                                */
# /* -------------------------------------------------------------------------- */
resource "aws_secretsmanager_secret" "service_json_secrets" {
  name        = "${local.service_name}/${random_string.service_secret_random_suffix.result}"
  description = "Secret for service ${local.service_name}"
  kms_key_id  = module.secret_kms_key.key_arn

  tags = merge({
    Name = "${local.service_name}"
  }, local.tags)

  provider = aws
}

resource "aws_secretsmanager_secret_version" "service_json_secrets" {
  secret_id     = aws_secretsmanager_secret.service_json_secrets.id
  secret_string = jsonencode(var.json_secrets)

  provider = aws
}

# We add a policy to the ECS Task Execution role so that ECS can pull secrets from SecretsManager and
# inject them as environment variables in the service
resource "aws_iam_role_policy" "task_execution_secrets" {
  count = var.is_create_iam_role ? 1 : 0

  name = "${local.service_name}-ecs-task-execution-secrets"
  role = local.task_execution_role_id

  policy = <<EOF
{
    "Statement": [
      {
        "Effect": "Allow",
        "Action": ["secretsmanager:GetSecretValue"],
        "Resource": ${jsonencode(format("%s/*", split("/", local.secret_manager_json_arn)[0]))}
      }
    ]
}
EOF
}

/* -------------------------------------------------------------------------- */
/*                             ECS Task Definition                            */
/* -------------------------------------------------------------------------- */
resource "aws_ecs_task_definition" "this" {
  family                   = local.service_name
  network_mode             = "awsvpc"
  requires_compatibilities = var.capacity_provider_strategy == null ? ["FARGATE"] : ["EC2"]
  cpu                      = local.is_apm_enabled ? var.service_info.cpu_allocation + var.apm_config.cpu : var.service_info.cpu_allocation
  memory                   = local.is_apm_enabled ? var.service_info.mem_allocation + var.apm_config.memory : var.service_info.mem_allocation
  execution_role_arn       = local.task_execution_role_arn
  task_role_arn            = local.task_role_arn

  container_definitions = var.capacity_provider_strategy == null ? local.container_definitions : local.container_definitions_ec2

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

  tags = merge(local.tags, { "Name" = local.service_name })
}

/* -------------------------------------------------------------------------- */
/*                                 ECS Service                                */
/* -------------------------------------------------------------------------- */
resource "aws_service_discovery_service" "service" {
  name = local.service_name

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
  name                    = format("%s", local.service_name)
  cluster                 = local.ecs_cluster_arn
  task_definition         = aws_ecs_task_definition.this.arn
  desired_count           = var.service_count
  enable_execute_command  = var.is_enable_execute_command
  enable_ecs_managed_tags = true
  launch_type             = var.capacity_provider_strategy == null ? "FARGATE" : null

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
    container_name = local.service_name
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
    for_each = var.is_attach_service_with_lb ? [true] : []
    content {
      target_group_arn = aws_lb_target_group.this[0].arn
      container_name   = local.service_name
      container_port   = var.service_info.port
    }
  }

  lifecycle {
    ignore_changes = [
      task_definition,
      desired_count
    ]
  }

  tags = merge(local.tags, { Name = format("%s", local.service_name) })
}

/* -------------------------------------------------------------------------- */
/*                             Auto Scaling Target                            */
/* -------------------------------------------------------------------------- */
resource "aws_appautoscaling_target" "this" {
  count = var.scaling_configuration == {} ? 0 : 1

  max_capacity       = var.scaling_configuration.capacity.max_capacity
  min_capacity       = var.scaling_configuration.capacity.min_capacity
  resource_id        = format("service/%s/%s", var.ecs_cluster_name, local.service_name)
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

/* -------------------------------------------------------------------------- */
/*                             Auto Scaling Policy                            */
/* -------------------------------------------------------------------------- */
resource "aws_appautoscaling_policy" "target_tracking_scaling_policies" {
  for_each = try(var.scaling_configuration.policy_type, null) == "TargetTrackingScaling" ? var.scaling_configuration.scaling_behaviors : {}

  depends_on = [aws_appautoscaling_target.this[0]]

  name               = format("%s-%s-scaling-policy", local.service_name, replace(each.key, "_", "-"))
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace

  policy_type = lookup(var.scaling_configuration, "policy_type", null)

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = lookup(each.value, "predefined_metric_type", null)
    }

    target_value       = lookup(each.value, "target_value", null)
    scale_in_cooldown  = lookup(each.value, "scale_in_cooldown", 180)
    scale_out_cooldown = lookup(each.value, "scale_out_cooldown", 60)
  }
}

resource "aws_appautoscaling_policy" "step_scaling_policies" {
  for_each = try(var.scaling_configuration.policy_type, null) == "StepScaling" ? var.scaling_configuration.scaling_behaviors : {}

  depends_on = [aws_appautoscaling_target.this[0]]

  name               = format("%s-%s-scaling-policy", local.service_name, replace(each.key, "_", "-"))
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace

  policy_type = lookup(var.scaling_configuration, "policy_type", null)

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = lookup(each.value, "cooldown", 60)
    metric_aggregation_type = lookup(each.value, "statistic", "Average")

    dynamic "step_adjustment" {
      for_each = each.value["scaling_adjustment"] > 0 ? [true] : []
      iterator = _null

      content {
        metric_interval_lower_bound = "0"
        metric_interval_upper_bound = ""
        scaling_adjustment          = lookup(each.value, "scaling_adjustment", null)
      }
    }

    dynamic "step_adjustment" {
      for_each = each.value["scaling_adjustment"] < 0 ? [true] : []
      iterator = _null

      content {
        metric_interval_lower_bound = ""
        metric_interval_upper_bound = "0"
        scaling_adjustment          = lookup(each.value, "scaling_adjustment", null)
      }
    }
  }
}

module "step_alarm" {
  source  = "oozou/cloudwatch-alarm/aws"
  version = "1.0.0"

  for_each = try(var.scaling_configuration.policy_type, null) == "StepScaling" ? var.scaling_configuration.scaling_behaviors : {}

  depends_on = [aws_appautoscaling_target.this[0]]

  prefix      = var.prefix
  environment = var.environment
  name        = format("%s-%s", local.service_name, replace(each.key, "_", "-"))

  alarm_description = format(
    "%s's %s %s %s in period %ss with %s datapoint",
    lookup(each.value, "metric_name", null),
    lookup(each.value, "statistic", null),
    lookup(each.value, "comparison_operator", null),
    lookup(each.value, "threshold", null),
    lookup(each.value, "period", null),
    lookup(each.value, "evaluation_periods", null)
  )

  comparison_operator = local.comparison_operators[lookup(each.value, "comparison_operator", null)]
  evaluation_periods  = lookup(each.value, "evaluation_periods", null)
  metric_name         = lookup(each.value, "metric_name", null)
  namespace           = "AWS/ECS"
  period              = lookup(each.value, "period", null)
  statistic           = lookup(each.value, "statistic", null)
  threshold           = lookup(each.value, "threshold", null)

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = local.service_name
  }

  alarm_actions = concat([aws_appautoscaling_policy.step_scaling_policies[each.key].arn], lookup(each.value, "alarm_actions", lookup(var.scaling_configuration, "default_alarm_actions", [])))

  tags = var.tags
}
