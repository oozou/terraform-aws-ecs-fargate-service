/* -------------------------------------------------------------------------- */
/*                                   Generic                                  */
/* -------------------------------------------------------------------------- */
variable "prefix" {
  description = "The prefix name of customer to be displayed in AWS console and resource"
  type        = string
}

variable "environment" {
  description = "Environment Variable used as a prefix"
  type        = string
}

variable "name" {
  description = "Name of the ECS cluster to create"
  type        = string
}

variable "tags" {
  description = "Custom tags which can be passed on to the AWS resources. They should be key value pairs having distinct keys"
  type        = map(any)
  default     = {}
}

/* -------------------------------------------------------------------------- */
/*                                    Role                                    */
/* -------------------------------------------------------------------------- */
variable "is_create_iam_role" {
  description = "Create the built in IAM role for task role and task exec role"
  type        = bool
  default     = true
}

/* -------------------------------------------------------------------------- */
/*                                  Task Role                                 */
/* -------------------------------------------------------------------------- */
variable "exists_task_role_arn" {
  description = "The existing arn of task role"
  type        = string
  default     = ""
}

variable "additional_ecs_task_role_policy_arns" {
  description = "List of policies ARNs to attach to the ECS Task Role. eg: { rds_arn = module.postgres_db.rds_policy_arn }"
  type        = list(string)
  default     = []
}

/* -------------------------------------------------------------------------- */
/*                               Task Exec Role                               */
/* -------------------------------------------------------------------------- */
variable "exists_task_execution_role_arn" {
  description = "The existing arn of task exec role"
  type        = string
  default     = null
}

variable "additional_ecs_task_execution_role_policy_arns" {
  description = "List of policies ARNs to attach to the ECS Task Role. eg: { rds_arn = module.postgres_db.rds_policy_arn }"
  type        = list(string)
  default     = []
}











# /* -------------------------------------------------------------------------- */
# /*                               Fargate Service                              */
# /* -------------------------------------------------------------------------- */

# variable "service_image" {
#   description = "Image name for the container"
#   type        = string
# }

# variable "enable_execute_command" {
#   description = "Specifies whether to enable Amazon ECS Exec for the tasks within the service."
#   type        = bool
#   default     = false
# }

# variable "service_count" {
#   description = "Number of containers to deploy"
#   type        = number
#   default     = 1
# }

# variable "service_port" {
#   description = "Port for the service to listen on"
#   type        = number
# }

# variable "cpu" {
#   description = "CPU (MHz) to dedicate to each deployed container. See https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html for valid value for Fargate tasks. For Eg: 512 "
#   type        = string
# }

# variable "memory" {
#   description = "Memory to dedicate to each deployed container. See https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html for valid value for Fargate tasks. For Eg: 512"
#   type        = string
# }

# variable "attach_lb" {
#   description = "Attach the container to the public ALB? (true/false)"
#   type        = bool
# }

# variable "alb_listener_arn" {
#   description = "The ALB listener to attach to"
#   type        = string
#   default     = ""
# }

# variable "alb_path" {
#   description = "Mention Path For ALB routing eg: / or /route1"
#   type        = string
#   default     = ""
# }

# variable "alb_host_header" {
#   description = "Mention host header for api endpoint"
#   type        = string
#   default     = null
# }

# variable "alb_priority" {
#   description = "Priority of ALB rule https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-listeners.html#listener-rules"
#   type        = string
#   default     = "100"
# }

# variable "ecs_cluster_name" {
#   description = "ECS Cluster name to deploy in"
#   type        = string
# }

# variable "service_discovery_namespace" {
#   description = "DNS Namespace to deploy to"
#   type        = string
# }

# variable "security_groups" {
#   description = "Security groups to apply to service"
#   type        = list(string)
# }

# variable "vpc_id" {
#   description = "VPC id where security group is created"
#   type        = string
# }

# variable "subnets" {
#   description = "Subnet IDs to deploy into"
#   type        = list(string)
# }

# variable "envvars" {
#   description = "List of [{name = \"\", value = \"\"}] pairs of environment variables"
#   type = set(object({
#     name  = string
#     value = string
#   }))
#   default = [{
#     name  = "EXAMPLE_ENV"
#     value = "example"
#   }]
# }

# variable "email_ids" {
#   description = "List of email ids where alerts are to be published"
#   type        = list(string)
#   default     = []
# }

# variable "health_check" {
#   description = "Health Check Config for the service"
#   type        = map(string)

#   default = {
#     interval            = 20
#     path                = ""
#     timeout             = 10
#     healthy_threshold   = 3
#     unhealthy_threshold = 3
#     matcher             = "200,201,204"
#   }
# }

# variable "secrets" {
#   description = "Map of secret name(as reflected in Secrets Manager) and secret JSON string associated"
#   type        = map(any)
#   default     = {}
# }

# variable "json_secrets" {
#   description = "Map of secret name(as reflected in Secrets Manager) and secret JSON string associated"
#   type        = map(string)
#   default     = {}
# }

# variable "account_alias" {
#   description = "Alias of the AWS account where this service is created. Eg. alpha/beta/prod. This would be used create s3 bucket path in the logging account"
#   type        = string
# }

# variable "apm_sidecar_ecr_url" {
#   description = "[Optional] To enable APM, set Sidecar ECR URL"
#   type        = string
#   default     = ""
# }

# variable "apm_config" {
#   description = "Config for X-Ray sidecar container for APM and traceability"
#   type = object({
#     service_port = number
#     cpu          = number
#     memory       = number
#   })
#   default = {
#     service_port = 9000
#     cpu          = 256
#     memory       = 512
#   }
# }

# # variable "log_aggregation_s3" {
# #   description = "[Required] S3 details where logs are stored"
# #   type = object({
# #     bucket_name = string
# #     kms_key_arn = string
# #   })
# # }
