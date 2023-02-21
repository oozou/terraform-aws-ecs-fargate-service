data "aws_caller_identity" "this" {}
data "aws_region" "this" {}

locals {
  name = format("%s-%s-%s", var.prefix, var.environment, var.name)
}

/* -------------------------------------------------------------------------- */
/*                                     VPC                                    */
/* -------------------------------------------------------------------------- */
module "vpc" {
  source  = "oozou/vpc/aws"
  version = "1.2.4"

  prefix       = var.prefix
  environment  = var.environment
  account_mode = "spoke"

  cidr              = "172.17.170.128/25"
  public_subnets    = ["172.17.170.192/28", "172.17.170.208/28"]
  private_subnets   = ["172.17.170.224/28", "172.17.170.240/28"]
  database_subnets  = ["172.17.170.128/27", "172.17.170.160/27"]
  availability_zone = ["ap-southeast-1b", "ap-southeast-1c"]

  is_create_nat_gateway             = true
  is_enable_single_nat_gateway      = true
  is_enable_dns_hostnames           = true
  is_enable_dns_support             = true
  is_create_flow_log                = false
  is_enable_flow_log_s3_integration = false

  tags = var.custom_tags
}

/* -------------------------------------------------------------------------- */
/*                               Fargate Cluster                              */
/* -------------------------------------------------------------------------- */
module "fargate_cluster" {
  source  = "oozou/ecs-fargate-cluster/aws"
  version = "1.0.7"

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

  additional_security_group_ingress_rules = {}

  # ALB
  is_create_alb                  = true
  is_public_alb                  = true
  enable_deletion_protection     = false
  alb_listener_port              = 80
  is_ignore_unsecured_connection = true
  # alb_certificate_arn        = var.alb_certificate_arn
  public_subnet_ids = module.vpc.public_subnet_ids # If is_public_alb is true, public_subnet_ids is required

  # ALB's DNS Record
  is_create_alb_dns_record = false

  tags = var.custom_tags
}

/* -------------------------------------------------------------------------- */
/*                                   Service                                  */
/* -------------------------------------------------------------------------- */
module "service_api" {
  source = "../.."

  prefix      = var.prefix
  environment = var.environment
  name        = format("%s-api-service", var.name)

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

  is_create_cloudwatch_log_group = true

  container = {
    main_container = {
      name            = format("%s-api-service", local.name)
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
      environment_variables = {
        THIS_IS_ENV  = "ENV1",
        THIS_IS_ENVV = "ENVV",
      }
      secret_variables = { # WARNING Secret should not be in plain text
        THIS_IS_SECRET  = "1xxxxx",
        THIS_IS_SECRETT = "2xxxxx",
      }
      entry_point = []
      command     = []
      # health_check = {
      #   interval            = 20,
      #   path                = "",
      #   timeout             = 10,
      #   healthy_threshold   = 3,
      #   unhealthy_threshold = 3,
      #   matcher             = "200,201,204"
      # }
    }
    side_container = {
      name   = format("%s-nginx", local.name)
      image  = "tutum/dnsutils"
      cpu    = 128
      memory = 256
      port_mappings = [
        {
          host_port      = 443
          container_port = 443
          protocol       = "tcp"
        },
      ]
      environment_variables = {
        XXXX  = "XXXX",
        XXXXX = "XXXXX",
      }
      secret_variables = { # WARNING Secret should not be in plain text
        AA = "AAAAA",
        A  = "AAA",
      }
    }
  }

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

output "debug" {
  value = module.service_api.debug
}
