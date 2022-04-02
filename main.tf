/* -------------------------------------------------------------------------- */
/*                                  Generics                                  */
/* -------------------------------------------------------------------------- */
/* ---------------------------------- Data ---------------------------------- */
# data "aws_caller_identity" "current" {
# }

# data "aws_region" "current" {
# }
/* --------------------------------- Locals --------------------------------- */
locals {
  service_name = format("%s-%s-%s", var.prefix, var.environment, var.name)

  # IAM Role
  task_role_arn                     = var.is_create_iam_role ? aws_iam_role.task_role[0].arn : var.exists_task_role_arn
  task_role_name                    = try(split("/", local.task_role_arn)[1], "")
  task_role_id                      = local.task_role_name
  ecs_default_task_role_policy_arns = ["arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"]
  ecs_task_role_policy_arns         = toset(concat(var.ecs_task_role_policy_arns, local.ecs_default_task_role_policy_arns))






  # log_group_name = format("%s-service-log-group", local.service_name)

  # ecs_cluster_arn = "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.ecs_cluster_name}"
  # apm_name               = "xray-apm-sidecar"
  # enable_alb_host_header = var.alb_host_header != null ? true : false


  # task_execution_role_arn = !var.is_create_iam_role && var.exists_task_execution_role_arn != null ? var.exists_task_execution_role_arn : aws_iam_role.task_execution[0].arn
  # task_execution_role_id  = split("/", local.task_execution_role_arn)[1]

  # is_apm_enabled = signum(length(trimspace(var.apm_sidecar_ecr_url))) == 1



  tags = merge(
    {
      "Environment" = var.environment,
      "Terraform"   = "true"
    },
    var.tags
  )
}
/* ----------------------------- Raise Xondition ---------------------------- */
locals {
  raise_task_role_arn_required = !var.is_create_iam_role && length(var.exists_task_role_arn) == 0 ? file("Variable `exists_task_role_arn` is required when `is_create_iam_role` is false") : "pass"
}
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
# resource "aws_iam_role" "task_execution" {
#   count = var.is_create_iam_role ? 1 : 0
#   name               = "${local.service_name}-ecs-task-execution-role"
#   assume_role_policy = data.aws_iam_policy_document.task_execution_assume_role_policy.json

#   tags = merge({
#     Name = "${local.service_name}-task-execution-role"
#   }, local.tags)

#   provider = aws.service
# }

# data "aws_iam_policy_document" "task_execution_assume_role_policy" {
#   statement {
#     sid     = ""
#     effect  = "Allow"
#     actions = ["sts:AssumeRole"]

#     principals {
#       type        = "Service"
#       identifiers = ["ecs-tasks.amazonaws.com"]
#     }
#   }

#   provider = aws.service
# }

# resource "aws_iam_role_policy_attachment" "task_execution" {
#   # role       = aws_iam_role.task_execution.id
#   role       = local.task_execution_role_id
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"

#   provider = aws.service
# }

/* -------------------------------------------------------------------------- */
/*                                 CloudWatch                                 */
/* -------------------------------------------------------------------------- */
# resource "aws_cloudwatch_log_group" "main" {
#   name              = "${local.service_name}-service-log-group"
#   retention_in_days = 30

#   tags = merge({
#     Name = "${local.service_name}-service-log-group"
#   }, local.tags)

# }

/* -------------------------------------------------------------------------- */
/*                                Load Balancer                               */
/* -------------------------------------------------------------------------- */
/* ----------------------------- LB Target Group ---------------------------- */
# resource "aws_lb_target_group" "main" {
#   count       = var.attach_lb ? 1 : 0
#   name        = substr(local.service_name, 0, min(32, length(local.service_name)))
#   port        = var.service_port
#   protocol    = var.service_port == 443 ? "HTTPS" : "HTTP"
#   vpc_id      = var.vpc_id
#   target_type = "ip"

#   health_check {
#     interval            = var.health_check.interval
#     path                = var.health_check.path
#     timeout             = var.health_check.timeout
#     healthy_threshold   = var.health_check.healthy_threshold
#     unhealthy_threshold = var.health_check.unhealthy_threshold
#     matcher             = var.health_check.matcher
#   }

#   tags = merge({
#     Name = "${local.service_name}-tg"
#   }, local.tags)

# }
/* ------------------------------ Listener Rule ----------------------------- */
# resource "aws_lb_listener_rule" "main" {
#   count        = var.attach_lb ? 1 : 0
#   listener_arn = var.alb_listener_arn
#   priority     = var.alb_priority

#   action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.main[0].arn
#   }

#   condition {
#     path_pattern {
#       values = [var.alb_path == "" ? "*" : var.alb_path]
#     }
#   }

#   dynamic "condition" {
#     for_each = local.enable_alb_host_header ? [true] : []
#     content {
#       host_header {
#         values = [var.alb_host_header]
#       }
#     }
#   }

# }


/* -------------------------------------------------------------------------- */
/*                             ECS Task Definition                            */
/* -------------------------------------------------------------------------- */
# resource "aws_ecs_task_definition" "service_with_apm" {
#   count                    = local.is_apm_enabled ? 1 : 0
#   family                   = local.service_name
#   network_mode             = "awsvpc"
#   requires_compatibilities = ["FARGATE"]
#   cpu                      = var.cpu + var.apm_config.cpu
#   memory                   = var.memory + var.apm_config.memory
#   execution_role_arn       = local.task_execution_role_arn
#   task_role_arn            = local.task_role_arn

#   container_definitions = templatefile("${path.module}/task-definitions/service-with-sidecar-container.json", {
#     cpu                     = var.cpu
#     service_image           = var.service_image
#     memory                  = var.memory
#     log_group_name          = local.log_group_name
#     region                  = data.aws_region.current.name
#     service_name            = local.service_name
#     service_port            = var.service_port
#     envvars                 = jsonencode(var.envvars)
#     secrets_task_definition = jsonencode(local.secrets_task_definition)
#     apm_cpu                 = var.apm_config.cpu
#     apm_sidecar_ecr_url     = var.apm_sidecar_ecr_url
#     apm_memory              = var.apm_config.memory
#     apm_name                = local.apm_name
#     apm_service_port        = var.apm_config.service_port
#   })


#   tags = merge({
#     Name = local.service_name
#   }, local.tags)

# }

# resource "aws_ecs_task_definition" "service" {
#   count                    = local.is_apm_enabled ? 0 : 1
#   family                   = local.service_name
#   network_mode             = "awsvpc"
#   requires_compatibilities = ["FARGATE"]
#   cpu                      = var.cpu
#   memory                   = var.memory
#   execution_role_arn       = local.task_execution_role_arn
#   task_role_arn            = local.task_role_arn

#   container_definitions = templatefile("${path.module}/task-definitions/service-main-container.json", {
#     cpu                     = var.cpu
#     service_image           = var.service_image
#     memory                  = var.memory
#     log_group_name          = local.log_group_name
#     region                  = data.aws_region.current.name
#     service_name            = local.service_name
#     service_port            = var.service_port
#     envvars                 = jsonencode(var.envvars)
#     secrets_task_definition = jsonencode(local.secrets_task_definition)
#   })


#   tags = merge({
#     Name = local.service_name
#   }, local.tags)

# }

# resource "aws_ecs_task_definition" "service_with_apm" {
#   count                    = local.is_apm_enabled ? 1 : 0
#   family                   = local.service_name
#   network_mode             = "awsvpc"
#   requires_compatibilities = ["FARGATE"]
#   cpu                      = var.cpu + var.apm_config.cpu
#   memory                   = var.memory + var.apm_config.memory
#   execution_role_arn       = local.task_execution_role_arn
#   task_role_arn            = local.task_role_arn

#   container_definitions = templatefile("${path.module}/task-definitions/service-with-sidecar-container.json", {
#     cpu                     = var.cpu
#     service_image           = var.service_image
#     memory                  = var.memory
#     log_group_name          = local.log_group_name
#     region                  = data.aws_region.current.name
#     service_name            = local.service_name
#     service_port            = var.service_port
#     envvars                 = jsonencode(var.envvars)
#     secrets_task_definition = jsonencode(local.secrets_task_definition)
#     apm_cpu                 = var.apm_config.cpu
#     apm_sidecar_ecr_url     = var.apm_sidecar_ecr_url
#     apm_memory              = var.apm_config.memory
#     apm_name                = local.apm_name
#     apm_service_port        = var.apm_config.service_port
#   })


#   tags = merge({
#     Name = local.service_name
#   }, local.tags)

# }

/* -------------------------------------------------------------------------- */
/*                                 ECS Service                                */
/* -------------------------------------------------------------------------- */
# resource "aws_service_discovery_service" "service" {
#   name = local.service_name

#   dns_config {
#     namespace_id = var.service_discovery_namespace

#     dns_records {
#       ttl  = 10
#       type = "A"
#     }

#     routing_policy = "MULTIVALUE"
#   }

#   health_check_custom_config {
#     failure_threshold = 1
#   }

# }

# resource "aws_ecs_service" "this" {
#   count = var.attach_lb ? 1 : 0 # TODO make this one more generics (public, private)

#   name                   = format("%s-service", local.service_name)
#   cluster                = local.ecs_cluster_arn
#   task_definition        = (local.is_apm_enabled ? aws_ecs_task_definition.service_with_apm[0].arn : aws_ecs_task_definition.service[0].arn)
#   desired_count          = var.service_count
#   enable_execute_command = var.is_enable_execute_command ##
#   launch_type            = "FARGATE"

#   network_configuration {
#     security_groups = var.security_groups
#     subnets         = var.subnets
#   }

#   service_registries {
#     registry_arn   = aws_service_discovery_service.service.arn
#     container_name = local.service_name
#   }

#   # TODO Private don't have
#   load_balancer {
#     target_group_arn = aws_lb_target_group.main[0].arn
#     container_name   = local.service_name
#     container_port   = var.service_port
#   }

#   lifecycle {
#     ignore_changes = [task_definition]
#   }

#   tags = merge(local.tags, { Name = format("%s-service", local.service_name) })
# }
