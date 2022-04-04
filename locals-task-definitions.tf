locals {
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
  })
}
