variable "service_name" {
  description = "Name of the service"
  type        = string
}

variable "service_image" {
  description = "Image name for the container"
  type        = string
}

variable "service_count" {
  description = "Number of containers to deploy"
  type        = number
  default     = 1
}

variable "service_port" {
  description = "Port for the service to listen on"
  type        = number
}

variable "cpu" {
  description = "CPU (MHz) to dedicate to each deployed container. See https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html for valid value for Fargate tasks. For Eg: 512 "
  type        = string
}

variable "memory" {
  description = "Memory to dedicate to each deployed container. See https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html for valid value for Fargate tasks. For Eg: 512"
  type        = string
}

variable "attach_lb" {
  description = "Attach the container to the public ALB? (true/false)"
  type        = bool
}

variable "alb_listener_arn" {
  description = "The ALB listener to attach to"
  type        = string
  default     = ""
}

variable "alb_path" {
  description = "Mention Path For ALB routing eg: / or /route1"
  type        = string
  default     = ""
}

variable "alb_priority" {
  description = "Priority of ALB rule https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-listeners.html#listener-rules"
  type        = string
  default     = "100"
}

variable "ecs_cluster_name" {
  description = "ECS Cluster name to deploy in"
  type        = string
}

variable "ecs_task_role_policy_arns" {
  description = "Map of policies ARNs to attach to the ECS Task Role. eg: { rds_arn = module.postgres_db.rds_policy_arn }"
  type        = map(string)
  default     = {}
}

variable "service_discovery_namespace" {
  description = "DNS Namespace to deploy to"
  type        = string
}

variable "security_groups" {
  description = "Security groups to apply to service"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC id where security group is created"
  type        = string
}

variable "subnets" {
  description = "Subnet IDs to deploy into"
  type        = list(string)
}

variable "envvars" {
  description = "List of [{name = \"\", value = \"\"}] pairs of environment variables"
  type = set(object({
    name  = string
    value = string
  }))
  default = [{
    name  = "EXAMPLE_ENV"
    value = "example"
  }]
}

variable "email_ids" {
  description = "List of email ids where alerts are to be published"
  type        = list(string)
  default     = []
}

variable "health_check" {
  description = "Health Check Config for the service"
  type        = map(string)

  default = {
    interval            = 20
    path                = ""
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200,201,204"
  }
}

variable "secrets" {
  description = "Map of secret name(as reflected in Secrets Manager) and secret JSON string associated"
  type        = map(any)
  default     = {}
}

variable "account_alias" {
  description = "Alias of the AWS account where this service is created. Eg. alpha/beta/prod. This would be used create s3 bucket path in the logging account"
  type        = string
}

# variable "log_aggregation_s3" {
#   description = "[Required] S3 details where logs are stored"
#   type = object({
#     bucket_name = string
#     kms_key_arn = string
#   })
# }

variable "custom_tags" {
  description = "Custom tags which can be passed on to the AWS resources. They should be key value pairs having distinct keys"
  type        = map(any)
  default     = {}
}

variable "apm_sidecar_ecr_url" {
  description = "[Optional] To enable APM, set Sidecar ECR URL"
  type        = string
  default     = ""
}

variable "apm_config" {
  description = "Config for X-Ray sidecar container for APM and traceability"
  type = object({
    service_port = number
    cpu          = number
    memory       = number
  })
  default = {
    service_port = 9000
    cpu          = 256
    memory       = 512
  }
}
