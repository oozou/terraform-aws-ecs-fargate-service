/* -------------------------------------------------------------------------- */
/*                                   Generic                                  */
/* -------------------------------------------------------------------------- */
variable "name_override" {
  description = "(Optional) Full name to override usage from format(\"%s-%s-%s-cf\", var.prefix, var.environment, var.name)"
  type        = string
  default     = ""
}

variable "prefix" {
  description = "(Optional) Prefix as a part of format(\"%s-%s-%s-cf\", var.prefix, var.environment, var.name); ex. oozou-xxx-xxx-cf"
  type        = string
  default     = ""
}

variable "environment" {
  description = "(Optional) Environment as a part of format(\"%s-%s-%s-cf\", var.prefix, var.environment, var.name); ex. xxx-prod-xxx-cf"
  type        = string
  default     = ""
}

variable "name" {
  description = "(Optional) Name as a part of format(\"%s-%s-%s-cf\", var.prefix, var.environment, var.name); ex. xxx-xxx-cms-cf"
  type        = string
  default     = ""
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

variable "cloudwatch_log_retention_in_days" {
  description = "Retention day for cloudwatch log group"
  type        = number
  default     = 90
}

variable "cloudwatch_log_kms_key_id" {
  description = "The ARN for the KMS encryption key."
  type        = string
  default     = null
}

/* -------------------------------------------------------------------------- */
/*                                LoadBalancer                                */
/* -------------------------------------------------------------------------- */
/* ----------------------------- LB Target Group ---------------------------- */
variable "is_attach_service_with_lb" {
  description = "Attach the container to the public ALB? (true/false)"
  type        = bool
}

variable "target_group_deregistration_delay" {
  description = "(Optional) Amount time for Elastic Load Balancing to wait before changing the state of a deregistering target from draining to unused. The range is 0-3600 seconds. The default value is 300 seconds."
  type        = number
  default     = 300
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

variable "alb_paths" {
  description = "Mention list Path For ALB routing eg: [\"/\"] or [\"/route1\"]"
  type        = list(string)
  default     = []
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
variable "secret_variables" {
  description = "Map of secret name(as reflected in Secrets Manager) and secret JSON string associated"
  type        = map(string)
  default     = {}
}

variable "environment_variables" {
  description = "Map of environment varaibles ex. { RDS_ENDPOINT = \"admin@rds@123\"}"
  type        = map(any)
  default     = {}
}

/* -------------------------------------------------------------------------- */
/*                               Task Definition                              */
/* -------------------------------------------------------------------------- */
variable "service_info" {
  description = "The configuration of service"
  type = object({
    cpu_allocation = number
    mem_allocation = number
    port           = number
    image          = string
    mount_points   = list(any)
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

variable "is_application_scratch_volume_enabled" {
  description = "To enabled the temporary storage for the service"
  type        = bool
  default     = false
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

/* -------------------------------------------------------------------------- */
/*                             Auto Scaling Group                             */
/* -------------------------------------------------------------------------- */
variable "scaling_configuration" {
  description = <<EOF
  configuration of scaling configuration support both target tracking and step scaling policies
  https://docs.aws.amazon.com/autoscaling/application/APIReference/API_PredefinedMetricSpecification.html
  https://docs.aws.amazon.com/AmazonECS/latest/developerguide/cloudwatch-metrics.html
  EOF
  type        = any
  default     = {}
}

/* -------------------------------------------------------------------------- */
/*                      capacity provider strategy                            */
/* -------------------------------------------------------------------------- */
variable "capacity_provider_strategy" {
  description = "Capacity provider strategies to use for the service EC2 Autoscaling group"
  type        = map(any)
  default     = null
}

variable "ordered_placement_strategy" {
  description = "Service level strategy rules that are taken into consideration during task placement"
  type = set(object({
    type  = string
    field = string
  }))
  default = [{
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }]
}

variable "unix_max_connection" {
  description = "Number of net.core.somaxconn"
  type        = number
  default     = 4096
}

/* -------------------------------------------------------------------------- */
/*                           Entrypoint and command                           */
/* -------------------------------------------------------------------------- */
variable "entry_point" {
  description = "Entrypoint to override"
  type        = list(string)
  default     = []
}

variable "command" {
  description = "Command to override"
  type        = list(string)
  default     = []
}

/* -------------------------------------------------------------------------- */
/*                                   volume                                   */
/* -------------------------------------------------------------------------- */
variable "efs_volumes" {
  description = "Task EFS volume definitions as list of configuration objects. You cannot define both Docker volumes and EFS volumes on the same task definition."
  type        = list(any)
  default     = []
}

/* -------------------------------------------------------------------------- */
/*                                   Rollback                                 */
/* -------------------------------------------------------------------------- */
variable "deployment_circuit_breaker" {
  description = "Configuration block for deployment circuit breaker"
  type = object({
    enable   = bool
    rollback = bool
  })
  default = {
    enable   = true
    rollback = true
  }
}
