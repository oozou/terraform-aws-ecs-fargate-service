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

  # ECS Service
  ecs_cluster_arn = "arn:aws:ecs:${data.aws_region.this.name}:${data.aws_caller_identity.this.account_id}:cluster/${var.ecs_cluster_name}"

  container_attahced_to_alb_keys = [for key, container in var.container : key if try(container.is_attach_to_lb, false) == true]
  is_create_target_group         = length(local.container_attahced_to_alb_keys) == 1
  container_target_group_object  = try(var.container[local.container_attahced_to_alb_keys[0]], {})

  # KMS
  /*| a | b | (a: enable default kms, b: use custom kms)
    |---|---|
    | 0 | 0 | no create
    | 0 | 1 | use custom kms
    | 1 | 0 | use default kms
    | 1 | 1 | use custom kms */
  cloudwatch_log_group_kms_key_arn = var.is_create_cloudwatch_log_group ? var.cloudwatch_log_group_kms_key_arn != null ? var.cloudwatch_log_group_kms_key_arn : var.is_create_default_kms ? module.cloudwatch_log_group_kms[0].key_arn : null : null

  secret_kms_key_arn = var.is_create_default_kms && var.secret_kms_key_arn == null ? module.secret_kms_key[0].key_arn : var.secret_kms_key_arn

  tags = merge(
    {
      "Environment" = var.environment,
      "Terraform"   = "true"
      "Module"      = "terraform-aws-ecs-fargate-service"
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
  raise_enable_exec_on_cp                = var.is_enable_execute_command && var.capacity_provider_strategy != null ? file("Canot set `is_enable_execute_command` with `capacity_provider_strategy`. Please enabled SSM at EC2 instance profile instead") : "pass"
  raise_multiple_container_attach_to_alb = length(local.container_attahced_to_alb_keys) > 1 ? file("var.container[*].is_attach_to_lb allow to be true only 1 key; found ${jsonencode(local.container_attahced_to_alb_keys)}") : null

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

  container_task_definitions = [for key, configuration in var.container :
    {
      name        = lookup(configuration, "name", null),
      image       = lookup(configuration, "image", null),
      networkMode = lookup(configuration, "network_mode", "awsvpc")
      cpu         = lookup(configuration, "cpu", null)
      memory      = lookup(configuration, "memory", null)
      essential   = lookup(configuration, "essential", true)
      portMappings = [for config in lookup(configuration, "port_mappings", []) :
        {
          containerPort = lookup(config, "container_port", null)
          hostPort      = lookup(config, "host_port", null)
          protocol      = lookup(config, "protocol", "tcp")
        }
      ]
      mountPoints = [for config in lookup(configuration, "mount_points", []) :
        {
          containerPath = lookup(config, "container_path", null)
          sourceVolume  = lookup(config, "source_volume", null)
          readOnly      = lookup(config, "read_only", false)
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = local.log_group_name
          "awslogs-region"        = data.aws_region.this.name
          "awslogs-stream-prefix" = lookup(configuration, "name", null),
        }
      }
      environment = [for key, value in try(var.environment_variables[key], {}) :
        {
          name  = key
          value = value
        }
      ]
      secrets = [for secret_name, secret_value in try(var.secret_variables[key], {}) :
        {
          name      = secret_name
          valueFrom = format("%s:%s::", aws_secretsmanager_secret_version.this[key].arn, secret_name)
        }
      ]
      entryPoint   = lookup(configuration, "entry_point", [])
      command      = lookup(configuration, "command", [])
      mount_points = concat(local.mount_points_application_scratch, lookup(configuration, "mount_points", []))
    }
  ]
}

/* -------------------------------------------------------------------------- */
/*                                Auto Scaling                                */
/* -------------------------------------------------------------------------- */
locals {
  is_created_aws_appautoscaling_target = var.target_tracking_configuration != {} || var.step_scaling_configuration != {}

  is_target_tracking_scaling   = var.target_tracking_configuration == {} ? false : true
  is_contain_predefined_metric = local.is_target_tracking_scaling ? try(var.target_tracking_configuration["scaling_behaviors"]["predefined_metric_type"], null) != null : false

  comparison_operators = {
    ">=" = "GreaterThanOrEqualToThreshold",
    ">"  = "GreaterThanThreshold",
    "<"  = "LessThanThreshold",
    "<=" = "LessThanOrEqualToThreshold",
  }
}
