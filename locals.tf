data "aws_caller_identity" "this" {}
data "aws_region" "this" {}

/* -------------------------------------------------------------------------- */
/*                                  Generics                                  */
/* -------------------------------------------------------------------------- */
locals {
  name = var.name_override == "" ? format("%s-%s-%s", var.prefix, var.environment, var.name) : var.name_override

  # Task Role
  task_role_arn  = var.is_create_iam_role ? aws_iam_role.task_role[0].arn : var.exists_task_role_arn
  task_role_name = try(split("/", local.task_role_arn)[1], "")

  # Task Exec Role
  task_execution_role_arn                     = var.is_create_iam_role ? aws_iam_role.task_execution_role[0].arn : var.exists_task_execution_role_arn
  task_execution_role_name                    = try(split("/", local.task_execution_role_arn)[1], "")
  task_execution_role_id                      = local.task_execution_role_name
  ecs_default_task_execution_role_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
  ecs_task_execution_role_policy_arns         = toset(concat(var.additional_ecs_task_execution_role_policy_arns, local.ecs_default_task_execution_role_policy_arns))

  # Logging
  log_group_name = format("%s-log-group", local.name)

  # Volume
  volumes = concat(var.efs_volumes)

  # APM
  is_apm_enabled = signum(length(trimspace(var.apm_sidecar_ecr_url))) == 1
  apm_name       = "xray-apm-sidecar"

  # ECS Service
  ecs_cluster_arn = "arn:aws:ecs:${data.aws_region.this.name}:${data.aws_caller_identity.this.account_id}:cluster/${var.ecs_cluster_name}"

  comparison_operators = {
    ">=" = "GreaterThanOrEqualToThreshold",
    ">"  = "GreaterThanThreshold",
    "<"  = "LessThanThreshold",
    "<=" = "LessThanOrEqualToThreshold",
  }

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

  empty_prefix      = var.prefix == "" ? true : false
  empty_environment = var.environment == "" ? true : false
  empty_name        = var.name == "" ? true : false
  raise_empty_name  = local.name == "" && (local.empty_prefix || local.empty_environment || local.empty_name) ? file("`var.name_override` or (`var.prefix`, `var.environment` and `var.name is required`) ") : null
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

  # Secret and Env
  secret_variables = [
    for secret_name, secret_value in var.secret_variables : {
      name      = secret_name,
      valueFrom = format("%s:%s::", aws_secretsmanager_secret_version.service_secrets.arn, secret_name)
    }
  ]
  environment_variables = [
    for key, value in var.environment_variables : {
      "name"  = key,
      "value" = value
    }
  ]

  pre_container_definitions_template = {
    cpu                   = var.service_info.cpu_allocation
    service_image         = var.service_info.image
    memory                = var.service_info.mem_allocation
    log_group_name        = local.log_group_name
    region                = data.aws_region.this.name
    name                  = local.name
    service_port          = var.service_info.port
    environment_variables = jsonencode(local.environment_variables)
    secret_variables      = jsonencode(local.secret_variables)
    entry_point           = jsonencode(var.entry_point)
    mount_points          = jsonencode(local.mount_points)
    command               = jsonencode(var.command)
  }
  apm_template = {
    apm_cpu             = var.apm_config.cpu
    apm_sidecar_ecr_url = var.apm_sidecar_ecr_url
    apm_memory          = var.apm_config.memory
    apm_name            = local.apm_name
    apm_service_port    = var.apm_config.service_port
  }
  ec2_template = {
    unix_max_connection = tostring(var.unix_max_connection)
  }
  container_definitions_template = local.is_apm_enabled ? merge(local.pre_container_definitions_template, local.apm_template) : local.pre_container_definitions_template
  render_container_definitions   = local.is_apm_enabled ? templatefile("${path.module}/task-definitions/service-with-sidecar-container.json", local.container_definitions_template) : templatefile("${path.module}/task-definitions/service-main-container.json", local.container_definitions_template)

  container_definitions     = local.render_container_definitions
  container_definitions_ec2 = templatefile("${path.module}/task-definitions/service-main-container-ec2.json", merge(local.pre_container_definitions_template, local.ec2_template))
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
