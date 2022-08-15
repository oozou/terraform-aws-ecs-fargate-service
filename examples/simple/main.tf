# Please see how to use fargate cluster at ooozou/terraform-aws-fargate-cluster

module "service_api" {
  source = "../.."

  # Generics
  prefix      = var.prefix
  environment = var.environment
  name        = format("%s-service-api", var.name)

  # IAM Role
  is_create_iam_role = true
  additional_ecs_task_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
  ]

  # ALB
  is_attach_service_with_lb = true
  alb_listener_arn          = module.fargate_cluster.alb_listener_http_arn
  alb_host_header           = null
  alb_paths                 = ["/*"]
  alb_priority              = "100"
  vpc_id                    = "vpc-xxxxxxx"
  health_check = {
    interval            = 20,
    path                = "/",
    timeout             = 10,
    healthy_threshold   = 3,
    unhealthy_threshold = 3,
    matcher             = "200,201,204"
  }

  # Logging
  is_create_cloudwatch_log_group = true

  # Task definition
  service_info = {
    containers_num = 2,
    cpu_allocation = 256,
    mem_allocation = 512,
    port           = 80,
    image          = "nginx"
  }

  # ECS service
  ecs_cluster_name            = module.fargate_cluster.ecs_cluster_name
  service_discovery_namespace = module.fargate_cluster.service_discovery_namespace
  is_enable_execute_command   = true
  application_subnet_ids      = ["subnet-xxxxxxxxx", "subnet-xxxxxx"]
  security_groups = [
    module.fargate_cluster.ecs_task_security_group_id
  ]

  tags = var.custom_tags
}
