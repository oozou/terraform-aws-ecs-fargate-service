# Please see how to use fargate cluster at ooozou/terraform-aws-fargate-cluster

module "fargate_cluster" {

  source = "git@github.com:oozou/terraform-aws-ecs-fargate-cluster?ref=v1.0.6"

  # Generics
  prefix      = var.prefix
  environment = var.environment
  name        = var.name

  # IAM Role
  ## If is_create_role is false, all of folowing argument is ignored
  is_create_role                 = true
  allow_access_from_principals   = ["arn:aws:iam::557291035693:root"]
  additional_managed_policy_arns = []

  # VPC Information
  vpc_id = module.vpc.vpc_id

  additional_security_group_ingress_rules = {}

  # ALB
  is_create_alb              = true
  is_public_alb              = true
  enable_deletion_protection = false
  alb_listener_port          = 8080
  # alb_certificate_arn        = var.alb_certificate_arn
  public_subnet_ids = module.vpc.public_subnet_ids # If is_public_alb is true, public_subnet_ids is required

  # ALB's DNS Record
  is_create_alb_dns_record = false

  tags = var.custom_tags
}

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
  is_attach_service_with_lb = false
  alb_listener_arn          = module.fargate_cluster.alb_listener_http_arn
  alb_host_header           = null
  alb_paths                 = ["/*"]
  alb_priority              = "100"
  vpc_id                    = module.vpc.vpc_id
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
    mount_points   = []
  }
  is_application_scratch_volume_enabled = true

  # ECS service
  ecs_cluster_name            = module.fargate_cluster.ecs_cluster_name
  service_discovery_namespace = module.fargate_cluster.service_discovery_namespace
  is_enable_execute_command   = true
  application_subnet_ids      = module.vpc.private_subnet_ids
  security_groups = [
    module.fargate_cluster.ecs_task_security_group_id
  ]

  tags = var.custom_tags
}
