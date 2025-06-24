/* -------------------------------------------------------------------------- */
/*                                   Data                                     */
/* -------------------------------------------------------------------------- */
data "aws_caller_identity" "this" {}

data "aws_availability_zones" "available" {
  state = "available"
}

/* -------------------------------------------------------------------------- */
/*                                     VPC                                    */
/* -------------------------------------------------------------------------- */
module "vpc" {
  source       = "oozou/vpc/aws"
  version      = "1.2.5"
  prefix       = var.prefix
  environment  = var.environment
  account_mode = "spoke"

  cidr              = "10.0.0.0/16"
  public_subnets    = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets   = ["10.0.3.0/24", "10.0.4.0/24"]
  availability_zone = slice(data.aws_availability_zones.available.names, 0, 2)

  is_create_nat_gateway             = true
  is_enable_single_nat_gateway      = true
  is_enable_dns_hostnames           = true
  is_enable_dns_support             = true
  is_create_flow_log                = false
  is_enable_flow_log_s3_integration = false

  tags = var.custom_tags
}

/* -------------------------------------------------------------------------- */
/*                                     ACM                                    */
/* -------------------------------------------------------------------------- */
module "acm" {
  source  = "oozou/acm/aws"
  version = "1.0.4"

  acms_domain_name         = {
  cms = {
    domain_name = "terraform-test.devops.team.oozou.com"
  }
}
  route53_zone_name        = "devops.team.oozou.com"
  is_automatic_verify_acms = true
}


/* -------------------------------------------------------------------------- */
/*                               Fargate Cluster                              */
/* -------------------------------------------------------------------------- */
module "fargate_cluster" {
  source  = "oozou/ecs-fargate-cluster/aws"
  version = "1.1.0"
  # Generics
  prefix      = var.prefix
  environment = var.environment
  name        = var.name

  # IAM Role
  ## If is_create_role is false, all of folowing argument is ignored
  is_create_role                 = true
  allow_access_from_principals   = ["arn:aws:iam::${data.aws_caller_identity.this.account_id}:root"]
  additional_managed_policy_arns = []

  # VPC Information
  vpc_id = module.vpc.vpc_id

  # ALB
  is_create_alb                  = true
  is_public_alb                  = true
  enable_deletion_protection     = false
  alb_listener_port              = 443
  is_ignore_unsecured_connection = true
  public_subnet_ids              = module.vpc.public_subnet_ids
  is_create_alb_dns_record       = true
  alb_certificate_arn            = module.acm.certificate_arns["cms"]
  route53_hosted_zone_name       = "devops.team.oozou.com"
  fully_qualified_domain_name    = "terraform-test.devops.team.oozou.com"


  tags = var.custom_tags
}

/* -------------------------------------------------------------------------- */
/*                                   Service                                  */
/* -------------------------------------------------------------------------- */
module "api_service" {
  source = "../.."

  prefix      = var.prefix
  environment = var.environment
  name        = format("%s-api-service", var.name)

  # ECS service
  task_cpu                    = 1024
  task_memory                 = 2048
  ecs_cluster_name            = module.fargate_cluster.ecs_cluster_name
  service_discovery_namespace = module.fargate_cluster.service_discovery_namespace
  is_enable_execute_command   = true
  application_subnet_ids      = module.vpc.private_subnet_ids
  security_groups = [
    module.fargate_cluster.ecs_task_security_group_id
  ]
  additional_ecs_task_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
  ]

  # ALB
  alb_listener_arn = module.fargate_cluster.alb_listener_http_arn
  alb_host_header  = null
  alb_paths        = ["/*"]
  alb_priority     = "100"
  vpc_id           = module.vpc.vpc_id
  health_check = {
    interval            = 20,
    path                = "/",
    timeout             = 10,
    healthy_threshold   = 3,
    unhealthy_threshold = 3,
    matcher             = "200,201,204"
  }

  is_create_cloudwatch_log_group = true

  container = {
    main_container = {
      name            = format("%s-%s-%s-api-service",var.prefix, var.environment, var.name)
      image           = "nginx"
      cpu             = 128
      memory          = 256
      is_attach_to_lb = true
      port_mappings = [
        {
          # If a container has multiple ports, index 0 will be used for target group
          host_port      = 80
          container_port = 80
          protocol       = "tcp"
        }
      ]
      entry_point = []
      command     = []
    }
  }
  environment_variables = {
    main_container = {
      THIS_IS_ENV  = "ENV1",
      THIS_IS_ENVV = "ENVV",
    }
    side_container = {
      XXXX  = "XXXX",
      XXXXX = "XXXXX",
    }
  }
  secret_variables = {
    main_container = {
      THIS_IS_SECRET  = "1xxxxx",
      THIS_IS_SECRETT = "2xxxxx",
    }
  }

  target_tracking_configuration = {
    policy_type = "TargetTrackingScaling"
    name        = "cpu-average"
    capacity = {
      min_capacity = 1
      max_capacity = 10
    }
    scaling_behaviors = {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
      target_value           = 60
      scale_in_cooldown      = 180
      scale_out_cooldown     = 60
    }
  }

  tags = var.custom_tags
}
