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
  for_each = var.is_create_iam_role ? local.ecs_task_role_policy_arns : []

  role       = local.task_role_name
  policy_arn = each.value
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
  retention_in_days = 30

  tags = merge(local.tags, { "Name" = local.log_group_name })
}

/* -------------------------------------------------------------------------- */
/*                                Load Balancer                               */
/* -------------------------------------------------------------------------- */
/* ----------------------------- LB Target Group ---------------------------- */
resource "aws_lb_target_group" "this" {
  count = var.is_attach_service_with_lb ? 1 : 0

  name        = format("%s-tg", local.service_name)
  port        = var.service_info.port
  protocol    = var.service_info.port == 443 ? "HTTPS" : "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

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
  source = "git@github.com:oozou/terraform-aws-kms-key.git?ref=v0.0.1"

  alias_name           = format("%s-service-secrets", local.service_name)
  append_random_suffix = true
  key_type             = "service"
  description          = format("Secure Secrets Manager's service secrets for service %s", local.service_name)

  service_key_info = {
    aws_service_names  = tolist([format("secretsmanager.%s.amazonaws.com", data.aws_region.current.name)])
    caller_account_ids = tolist([data.aws_caller_identity.current.account_id])
  }

  custom_tags = merge(local.tags, { "Name" : format("%s-service-secrets", local.service_name) })
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
  requires_compatibilities = ["FARGATE"]
  cpu                      = local.is_apm_enabled ? var.service_info.cpu_allocation + var.apm_config.cpu : var.service_info.cpu_allocation
  memory                   = local.is_apm_enabled ? var.service_info.mem_allocation + var.apm_config.memory : var.service_info.mem_allocation
  execution_role_arn       = local.task_execution_role_arn
  task_role_arn            = local.task_role_arn

  container_definitions = local.container_definitions

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
  name                   = format("%s", local.service_name)
  cluster                = local.ecs_cluster_arn
  task_definition        = aws_ecs_task_definition.this.arn
  desired_count          = var.service_count
  enable_execute_command = var.is_enable_execute_command
  launch_type            = "FARGATE"

  network_configuration {
    security_groups = var.security_groups
    subnets         = var.application_subnet_ids
  }

  service_registries {
    registry_arn   = aws_service_discovery_service.service.arn
    container_name = local.service_name
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
  max_capacity       = var.scaling_configuration.capacity.max_capacity
  min_capacity       = var.scaling_configuration.capacity.min_capacity
  resource_id        = format("service/%s/%s", var.ecs_cluster_name, local.service_name)
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

/* -------------------------------------------------------------------------- */
/*                          Auto Scaling Policy (UP)                          */
/* -------------------------------------------------------------------------- */
resource "aws_appautoscaling_policy" "scaling_policies" {
  for_each = var.scaling_configuration.scaling_behaviors

  depends_on = [aws_appautoscaling_target.this]

  name               = format("%s-%s-scaling-policy", local.service_name, each.key)
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  service_namespace  = aws_appautoscaling_target.this.service_namespace

  policy_type = lookup(var.scaling_configuration, "policy_type", null)

  dynamic "target_tracking_scaling_policy_configuration" {
    for_each = var.scaling_configuration.policy_type == "TargetTrackingScaling" ? var.scaling_configuration.scaling_behaviors[each.key] : {}

    content {
      predefined_metric_specification {
        predefined_metric_type = lookup(each.value, "predefined_metric_type", null)
      }

      target_value       = lookup(each.value, "target_value", null)
      scale_in_cooldown  = lookup(each.value, "scale_in_cooldown", 180)
      scale_out_cooldown = lookup(each.value, "scale_out_cooldown", 60)
    }
  }
}

# https://github.com/cn-terraform/terraform-aws-ecs-service-autoscaling/blob/main/main.tf
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target
