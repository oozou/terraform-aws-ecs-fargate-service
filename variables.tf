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
  default     = ""
}

variable "additional_ecs_task_execution_role_policy_arns" {
  description = "List of policies ARNs to attach to the ECS Task Role. eg: { rds_arn = module.postgres_db.rds_policy_arn }"
  type        = list(string)
  default     = []
}

/* -------------------------------------------------------------------------- */
/*                            CloudWatch Log Group                            */
/* -------------------------------------------------------------------------- */
variable "is_create_cloudwatch_log_group" {
  description = "Whether to create cloudwatch log group or not"
  type        = bool
  default     = true
}

/* -------------------------------------------------------------------------- */
/*                                LoadBalancer                                */
/* -------------------------------------------------------------------------- */
/* ----------------------------- LB Target Group ---------------------------- */
variable "is_attach_service_with_lb" {
  description = "Attach the container to the public ALB? (true/false)"
  type        = bool
}

variable "vpc_id" {
  description = "VPC id where security group is created"
  type        = string
  default     = ""
}

variable "health_check" {
  description = "Health Check Config for the service"
  type        = map(string)
  default     = {}
  # default = {
  #   interval            = 20
  #   path                = ""
  #   timeout             = 10
  #   healthy_threshold   = 3
  #   unhealthy_threshold = 3
  #   matcher             = "200,201,204"
  # }
}
/* ------------------------------ Listener Rule ----------------------------- */
variable "alb_listener_arn" {
  description = "The ALB listener to attach to"
  type        = string
  default     = ""
}

variable "alb_host_header" {
  description = "Mention host header for api endpoint"
  type        = string
  default     = null
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

variable "custom_header_token" {
  description = "[Required] Specify secret value for custom header"
  type        = string
  default     = ""
}

/* -------------------------------------------------------------------------- */
/*                                   Secret                                   */
/* -------------------------------------------------------------------------- */
variable "secrets" {
  description = "Map of secret name(as reflected in Secrets Manager) and secret JSON string associated"
  type        = map(string)
  default     = {}
}

variable "json_secrets" {
  description = "Map of secret name(as reflected in Secrets Manager) and secret JSON string associated"
  type        = map(string)
  default     = {}
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

/* -------------------------------------------------------------------------- */
/*                               Task Definition                              */
/* -------------------------------------------------------------------------- */
variable "service_info" {
  description = "The configuration of service"
  type = object({
    cpu_allocation = number
    mem_allocation = number
    containers_num = number
    port           = number
    image          = string
  })
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
/* -------------------------------------------------------------------------- */
/*                               Fargate Service                              */
/* -------------------------------------------------------------------------- */
variable "ecs_cluster_name" {
  description = "ECS Cluster name to deploy in"
  type        = string
}

variable "service_discovery_namespace" {
  description = "DNS Namespace to deploy to"
  type        = string
}

variable "service_count" {
  description = "Number of containers to deploy"
  type        = number
  default     = 1
}

variable "is_enable_execute_command" {
  description = "Specifies whether to enable Amazon ECS Exec for the tasks within the service."
  type        = bool
  default     = false
}

variable "application_subnet_ids" {
  description = "Subnet IDs to deploy into"
  type        = list(string)
}

variable "security_groups" {
  description = "Security groups to apply to service"
  type        = list(string)
}
