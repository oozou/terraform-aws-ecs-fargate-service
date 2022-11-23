data "aws_caller_identity" "current" {
}

data "aws_region" "current" {
}
/* -------------------------------------------------------------------------- */
/*                                  Generics                                  */
/* -------------------------------------------------------------------------- */
locals {
  service_name = format("%s-%s-%s", var.prefix, var.environment, var.name)

  # Task Role
  task_role_arn  = var.is_create_iam_role ? aws_iam_role.task_role[0].arn : var.exists_task_role_arn
  task_role_name = try(split("/", local.task_role_arn)[1], "")
  task_role_id   = local.task_role_name

  # Task Exec Role
  task_execution_role_arn                     = var.is_create_iam_role ? aws_iam_role.task_execution_role[0].arn : var.exists_task_execution_role_arn
  task_execution_role_name                    = try(split("/", local.task_execution_role_arn)[1], "")
  task_execution_role_id                      = local.task_execution_role_name
  ecs_default_task_execution_role_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
  ecs_task_execution_role_policy_arns         = toset(concat(var.additional_ecs_task_execution_role_policy_arns, local.ecs_default_task_execution_role_policy_arns))

  # Logging
  log_group_name = format("%s-service-log-group", local.service_name)

  # Volume
  volumes = concat(var.efs_volumes)

  # APM
  is_apm_enabled = signum(length(trimspace(var.apm_sidecar_ecr_url))) == 1
  apm_name       = "xray-apm-sidecar"

  # ECS Service
  ecs_cluster_arn = "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.ecs_cluster_name}"


  tags = merge(
    {
      "Environment" = var.environment,
      "Terraform"   = "true"
    },
    var.tags
  )
}

/* -------------------------------------------------------------------------- */
/*                               Raise Conidtion                              */
/* -------------------------------------------------------------------------- */
locals {
  raise_task_role_arn_required           = var.is_create_iam_role == false && length(var.exists_task_role_arn) == 0 ? file("Variable `exists_task_role_arn` is required when `is_create_iam_role` is false") : "pass"
  raise_task_execution_role_arn_required = var.is_create_iam_role == false && length(var.exists_task_execution_role_arn) == 0 ? file("Variable `exists_task_execution_role_arn` is required when `is_create_iam_role` is false") : "pass"

  raise_vpc_id_empty           = var.is_attach_service_with_lb && length(var.vpc_id) == 0 ? file("Variable `vpc_id` is required when `is_attach_service_with_lb` is true") : "pass"
  raise_service_port_empty     = var.is_attach_service_with_lb && var.service_info.port == null ? file("Variable `service_info.port` is required when `is_attach_service_with_lb` is true") : "pass"
  raise_health_check_empty     = var.is_attach_service_with_lb && var.health_check == {} ? file("Variable `health_check` is required when `is_attach_service_with_lb` is true") : "pass"
  raise_alb_listener_arn_empty = var.is_attach_service_with_lb && length(var.alb_listener_arn) == 0 ? file("Variable `alb_listener_arn` is required when `is_attach_service_with_lb` is true") : "pass"

  raise_enable_exec_on_cp = var.is_enable_execute_command && var.capacity_provider_strategy != null ? file("Canot set `is_enable_execute_command` with `capacity_provider_strategy`. Please enabled SSM at EC2 instance profile instead") : "pass"
}

/* -------------------------------------------------------------------------- */
/*                               Task Definition                              */
/* -------------------------------------------------------------------------- */
locals {
  mount_points_application_scratch = var.is_application_scratch_volume_enabled ? [
    {
      "containerPath" : "/var/scratch",
      "sourceVolume" : "application_scratch"
    }
  ] : []
  mount_points = concat(local.mount_points_application_scratch, try(var.service_info.mount_points, []))

  # TODO make it better later
  container_definitions = local.is_apm_enabled ? templatefile("${path.module}/task-definitions/service-with-sidecar-container.json", {
    cpu                     = var.service_info.cpu_allocation
    service_image           = var.service_info.image
    memory                  = var.service_info.mem_allocation
    log_group_name          = local.log_group_name
    region                  = data.aws_region.current.name
    service_name            = local.service_name
    service_port            = var.service_info.port
    envvars                 = jsonencode(var.envvars)
    secrets_task_definition = jsonencode(local.secrets_task_definition)
    apm_cpu                 = var.apm_config.cpu
    apm_sidecar_ecr_url     = var.apm_sidecar_ecr_url
    apm_memory              = var.apm_config.memory
    apm_name                = local.apm_name
    apm_service_port        = var.apm_config.service_port
    entry_point             = jsonencode(var.entry_point)
    command                 = jsonencode(var.command)
    mount_points            = jsonencode(local.mount_points)
    }) : templatefile("${path.module}/task-definitions/service-main-container.json", {
    cpu                     = var.service_info.cpu_allocation
    service_image           = var.service_info.image
    memory                  = var.service_info.mem_allocation
    log_group_name          = local.log_group_name
    region                  = data.aws_region.current.name
    service_name            = local.service_name
    service_port            = var.service_info.port
    envvars                 = jsonencode(var.envvars)
    secrets_task_definition = jsonencode(local.secrets_task_definition)
    entry_point             = jsonencode(var.entry_point)
    command                 = jsonencode(var.command)
    mount_points            = jsonencode(local.mount_points)
  })
  container_definitions_ec2 = templatefile("${path.module}/task-definitions/service-main-container-ec2.json", {
    cpu                     = var.service_info.cpu_allocation
    service_image           = var.service_info.image
    memory                  = var.service_info.mem_allocation
    log_group_name          = local.log_group_name
    region                  = data.aws_region.current.name
    service_name            = local.service_name
    service_port            = var.service_info.port
    envvars                 = jsonencode(var.envvars)
    secrets_task_definition = jsonencode(local.secrets_task_definition)
    entry_point             = jsonencode(var.entry_point)
    command                 = jsonencode(var.command)
    unix_max_connection     = tostring(var.unix_max_connection)
    mount_points            = jsonencode(local.mount_points)
  })
}

/* -------------------------------------------------------------------------- */
/*                                   SECRET                                   */
/* -------------------------------------------------------------------------- */
locals {
  # Create secret arn collection for granting "secretmanager:GetSecret" permission
  secret_manager_arns = [for secret in aws_secretsmanager_secret.service_secrets : secret.arn]

  # Get Secret Name Arrays
  secret_names = keys(var.secrets)

  # Create a secret map { secret_name : secret_arn } using ZipMap Function for iteration
  secrets_name_arn_map = zipmap(local.secret_names, local.secret_manager_arns)
  #
  # Create secrets format for Task Definition
  secrets_task_unique_definition = [for secret_key, secret_arn in local.secrets_name_arn_map :
    tomap({
      name      = upper(secret_key)
      valueFrom = secret_arn
    })
  ]
}

/* -------------------------------------------------------------------------- */
/*                                 JSON SECRET                                */
/* -------------------------------------------------------------------------- */
locals {
  # Get secret arn for granting  "secretmanager:GetSecret" permission
  secret_manager_json_arn = aws_secretsmanager_secret.service_json_secrets.arn

  # Map JSON Secret to Secret Arrays
  secrets_name_json_arn_map = { "JSON_SECRET" : local.secret_manager_json_arn }

  # Create secrets JSON format for Task Definition
  secrets_json_task_definition = [for secret_key, secret_arn in local.secrets_name_json_arn_map :
    tomap({
      name      = upper(secret_key)
      valueFrom = secret_arn
    })
  ]
  # Concat Secret and JSON Secret to the one list.
  secrets_task_definition = concat(local.secrets_task_unique_definition, local.secrets_json_task_definition)
}

/* -------------------------------------------------------------------------- */
/*                                Auto Scaling                                */
/* -------------------------------------------------------------------------- */
locals {
  comparison_operators = {
    ">=" = "GreaterThanOrEqualToThreshold",
    ">"  = "GreaterThanThreshold",
    "<"  = "LessThanThreshold",
    "<=" = "LessThanOrEqualToThreshold",
  }
}
