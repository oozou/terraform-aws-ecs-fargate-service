# Please see how to use fargate cluster at ooozou/terraform-aws-fargate-cluster

module "service_api" {
  source = "../.."

  # Generics
  prefix      = var.generics_info.prefix
  environment = var.generics_info.environment
  name        = format("%s-service-api", var.generics_info.name)

  # IAM Role
  is_create_iam_role = true
  additional_ecs_task_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
  ]

  # ALB
  is_attach_service_with_lb = true
  alb_listener_arn          = module.fargate_cluster.alb_listener_http_arn
  alb_host_header           = var.service_info["api"].service_alb_host_header
  alb_paths                 = var.service_info["api"].alb_paths
  alb_priority              = var.service_info["api"].alb_priority
  vpc_id                    = var.vpc_id
  health_check              = var.service_info["api"].health_check

  # Logging
  is_create_cloudwatch_log_group = true

  # Task definition
  service_info = var.service_info["api"].service_info

  # ECS service
  ecs_cluster_name            = module.fargate_cluster.ecs_cluster_name
  service_discovery_namespace = module.fargate_cluster.service_discovery_namespace
  is_enable_execute_command   = true
  application_subnet_ids      = var.subnet_ids
  security_groups = [
    module.fargate_cluster.ecs_task_security_group_id
  ]

  tags = var.generics_info.custom_tags
}