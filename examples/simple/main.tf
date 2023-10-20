data "aws_caller_identity" "this" {}

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
    path                = "",
    timeout             = 10,
    healthy_threshold   = 3,
    unhealthy_threshold = 3,
    matcher             = "200,201,204"
  }

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
      entry_point = []
      command     = []
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

  tags = var.custom_tags
}

module "payment_service" {
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
    path                = "",
    timeout             = 10,
    healthy_threshold   = 3,
    unhealthy_threshold = 3,
    matcher             = "200,201,204"
  }

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
      entry_point = []
      command     = []
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

  # target_tracking_configuration = {
  #   policy_type = "TargetTrackingScaling"
  #   name        = "cpu-average"
  #   capacity = {
  #     min_capacity = 1
  #     max_capacity = 10
  #   }
  #   scaling_behaviors = {
  #     predefined_metric_type = "ECSServiceAverageCPUUtilization"
  #     target_value           = 60
  #     scale_in_cooldown      = 180
  #     scale_out_cooldown     = 60
  #   }
  # }

  # target_tracking_configuration = {
  #   policy_type = "TargetTrackingScaling"
  #   name        = "concurrency-per-task"
  #   capacity = {
  #     min_capacity = 1
  #     max_capacity = 10
  #   }
  #   scaling_behaviors = {
  #     target_value       = 1500
  #     scale_in_cooldown  = 180
  #     scale_out_cooldown = 60
  #     custom_metrics = {
  #       active_connection_count = {
  #         id          = "acc"
  #         label       = "Get value of ActiveConnectionCount metric"
  #         return_data = false
  #         metric_stat = {
  #           stat        = "Sum"
  #           metric_name = "ActiveConnectionCount"
  #           namespace   = "AWS/ApplicationELB"
  #           dimensions = [
  #             {
  #               name  = "LoadBalancer"
  #               value = "app/oozou-devops-demo-alb/f0f65a9c9ea681e0"
  #             }
  #           ]
  #         }
  #       }
  #       running_task_count = {
  #         id          = "rtc"
  #         label       = "Get value of RunningTaskCount metric"
  #         return_data = false
  #         metric_stat = {
  #           stat        = "Average"
  #           metric_name = "RunningTaskCount"
  #           namespace   = "ECS/ContainerInsights"
  #           dimensions = [
  #             {
  #               name  = "ServiceName"
  #               value = "oozou-devops-demo-service-api"
  #             },
  #             {
  #               name  = "ClusterName"
  #               value = "oozou-devops-demo-cluster"
  #             },
  #           ]
  #         }
  #       }
  #       scaling_expression = {
  #         id          = "e1"
  #         label       = "ActiveConnectionCount/RunningTaskCount"
  #         expression  = "(acc)/rtc"
  #         return_data = true
  #       }
  #     }
  #   }
  # }

  # step_scaling_configuration = {
  #   policy_type = "StepScaling"
  #   capacity = {
  #     min_capacity = 1
  #     max_capacity = 10
  #   }
  #   scaling_behaviors = {
  #     cpu_up = {
  #       metric_name         = "CPUUtilization"
  #       namespace           = "AWS/ECS"
  #       statistic           = "Average"
  #       comparison_operator = ">="
  #       threshold           = "60"
  #       period              = "60"
  #       evaluation_periods  = "1"
  #       cooldown            = 60
  #       # If value in (threshold+lower_bound, threshold+upper_bound), in crease scaling_adjustment
  #       step_adjustment = [
  #         {
  #           # (60, 80) increase 1
  #           metric_interval_lower_bound = 0
  #           metric_interval_upper_bound = 20
  #           scaling_adjustment          = 1
  #         },
  #         {
  #           # (80, n) increase 2
  #           metric_interval_lower_bound = 20
  #           scaling_adjustment          = 2
  #         }
  #       ]
  #     }
  #     cpu_down = {
  #       metric_name         = "CPUUtilization"
  #       namespace           = "AWS/ECS"
  #       statistic           = "Average"
  #       comparison_operator = "<="
  #       threshold           = "40"
  #       period              = "60"
  #       evaluation_periods  = "2"
  #       cooldown            = 120
  #       step_adjustment = [
  #         # If value in (threshold+lower_bound, threshold+upper_bound), in crease scaling_adjustment
  #         {
  #           metric_interval_upper_bound = 0.0
  #           scaling_adjustment          = -1
  #         }
  #       ]
  #     }
  #   }
  # }

  step_scaling_configuration = {
    policy_type = "StepScaling"
    capacity = {
      min_capacity = 1
      max_capacity = 10
    }
    scaling_behaviors = {
      scaling_up = {
        metric_query = [
          {
            id = "acc"
            metric = [
              {
                metric_name = "RunningTaskCount"
                namespace   = "ECS/ContainerInsights"
                period      = "60"
                stat        = "Average"
                dimensions = {
                  ClusterName = "oozou-devops-demo-cluster"
                  ServiceName = "oozou-devops-demo-service-api"
                }
              }
            ]
          },
          {
            id = "rtc"
            metric = [
              {
                metric_name = "RunningTaskCount"
                namespace   = "ECS/ContainerInsights"
                period      = "60"
                stat        = "Average"
                dimensions = {
                  ClusterName = "oozou-devops-demo-cluster"
                  ServiceName = "oozou-devops-demo-service-api"
                }
              }
            ]
          },
          {
            id          = "e1"
            expression  = "acc*100/rtc"
            label       = "ActiveConnectionCount/RunningTaskCount"
            return_data = true
          }
        ]
        statistic           = "Average"
        comparison_operator = ">="
        evaluation_periods  = "1"
        threshold           = 1500
        cooldown            = 60
        # If value in (threshold+lower_bound, threshold+upper_bound), in crease scaling_adjustment
        step_adjustment = [
          {
            # (1500, 2500) increase 1
            metric_interval_lower_bound = 0
            metric_interval_upper_bound = 1000
            scaling_adjustment          = 1
          },
          {
            # (2500, 4500) increase 2
            metric_interval_lower_bound = 1000
            metric_interval_upper_bound = 3000
            scaling_adjustment          = 2
          },
          {
            # (4500, n) increase 4
            metric_interval_lower_bound = 3000
            scaling_adjustment          = 4
          }
        ]
      }
      cpu_down = {
        metric_query = [
          {
            id = "acc"
            metric = [
              {
                metric_name = "RunningTaskCount"
                namespace   = "ECS/ContainerInsights"
                period      = "60"
                stat        = "Average"
                dimensions = {
                  ClusterName = "oozou-devops-demo-cluster"
                  ServiceName = "oozou-devops-demo-service-api"
                }
              }
            ]
          },
          {
            id = "rtc"
            metric = [
              {
                metric_name = "RunningTaskCount"
                namespace   = "ECS/ContainerInsights"
                period      = "60"
                stat        = "Average"
                dimensions = {
                  ClusterName = "oozou-devops-demo-cluster"
                  ServiceName = "oozou-devops-demo-service-api"
                }
              }
            ]
          },
          {
            id          = "e1"
            expression  = "acc/rtc"
            label       = "ActiveConnectionCount/RunningTaskCount"
            return_data = true
          }
        ]
        statistic           = "Average"
        comparison_operator = "<="
        evaluation_periods  = "1"
        threshold           = 1300
        cooldown            = 60
        # If value in (threshold+lower_bound, threshold+upper_bound), in crease scaling_adjustment
        step_adjustment = [
          {
            # (0, 1300) increase 1
            metric_interval_upper_bound = 0
            scaling_adjustment          = -1
          }
        ]
      }
    }
  }

  tags = var.custom_tags
}
