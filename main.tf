locals {
  environment  = var.environment
  service_name = "${var.prefix}-${var.environment}-${var.name}"

  tags = merge(
    {
      "Environment" = local.environment,
      "Terraform"   = "true"
    },
    var.tags
  )
}

resource "aws_ecs_service" "public_service" {
  name                   = "${local.service_name}-service"
  cluster                = local.ecs_cluster_arn
  task_definition        = (local.is_apm_enabled ? aws_ecs_task_definition.service_with_apm[0].arn : aws_ecs_task_definition.service[0].arn)
  desired_count          = var.service_count
  enable_execute_command = var.enable_execute_command
  launch_type            = "FARGATE"
  count                  = var.attach_lb ? 1 : 0

  network_configuration {
    security_groups = var.security_groups
    subnets         = var.subnets
  }

  service_registries {
    registry_arn   = aws_service_discovery_service.service.arn
    container_name = local.service_name
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main[0].arn
    container_name   = local.service_name
    container_port   = var.service_port
  }

  # If CodePipeline deploys, don't upset TF
  lifecycle {
    ignore_changes = [task_definition]
  }

  tags = merge({
    Name = local.service_name
  }, local.tags)

  provider = aws.service
}

resource "aws_ecs_service" "private_service" {
  name                   = "${local.service_name}-service"
  cluster                = local.ecs_cluster_arn
  task_definition        = (local.is_apm_enabled ? aws_ecs_task_definition.service_with_apm[0].arn : aws_ecs_task_definition.service[0].arn)
  desired_count          = var.service_count
  enable_execute_command = var.enable_execute_command
  launch_type            = "FARGATE"
  count                  = var.attach_lb ? 0 : 1


  network_configuration {
    security_groups = var.security_groups
    subnets         = var.subnets
  }

  service_registries {
    registry_arn   = aws_service_discovery_service.service.arn
    container_name = local.service_name
  }

  lifecycle {
    ignore_changes = [task_definition]
  }

  tags = merge({
    Name = local.service_name
  }, local.tags)

  provider = aws.service
}

resource "aws_ecs_task_definition" "service" {
  count                    = local.is_apm_enabled ? 0 : 1
  family                   = local.service_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task_role.arn

  container_definitions = templatefile("${path.module}/task-definitions/service-main-container.json", {
    cpu                     = var.cpu
    service_image           = var.service_image
    memory                  = var.memory
    log_group_name          = local.log_group_name
    region                  = data.aws_region.active.name
    service_name            = local.service_name
    service_port            = var.service_port
    envvars                 = jsonencode(var.envvars)
    secrets_task_definition = jsonencode(local.secrets_task_definition)
  })


  tags = merge({
    Name = local.service_name
  }, local.tags)

  provider = aws.service
}

resource "aws_ecs_task_definition" "service_with_apm" {
  count                    = local.is_apm_enabled ? 1 : 0
  family                   = local.service_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu + var.apm_config.cpu
  memory                   = var.memory + var.apm_config.memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task_role.arn

  container_definitions = templatefile("${path.module}/task-definitions/service-with-sidecar-container.json", {
    cpu                     = var.cpu
    service_image           = var.service_image
    memory                  = var.memory
    log_group_name          = local.log_group_name
    region                  = data.aws_region.active.name
    service_name            = local.service_name
    service_port            = var.service_port
    envvars                 = jsonencode(var.envvars)
    secrets_task_definition = jsonencode(local.secrets_task_definition)
    apm_cpu                 = var.apm_config.cpu
    apm_sidecar_ecr_url     = var.apm_sidecar_ecr_url
    apm_memory              = var.apm_config.memory
    apm_name                = local.apm_name
    apm_service_port        = var.apm_config.service_port
  })


  tags = merge({
    Name = local.service_name
  }, local.tags)

  provider = aws.service
}

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

  provider = aws.service
}
