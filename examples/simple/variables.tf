variable "name" {
  description = "[Required] Name of Platfrom or application"
  type        = string
}

variable "prefix" {
  description = "[Required] Name prefix used for resource naming in this component"
  type        = string
}

variable "environment" {
  description = "[Required] Name prefix used for resource naming in this component"
  type        = string
}

variable "custom_tags" {
  description = "Custom tags which can be passed on to the AWS resources. They should be key value pairs having distinct keys."
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  type        = string
  description = "VPC ID to deploy"
}

variable "subnet_ids" {
  description = "A list of subnet IDs to launch resources in"
  type        = list(string)
}

variable "service_info" {
  description = <<EOF
  is_attach_service_with_lb >> Attach the container to the public ALB? (true/false)
  service_alb_host_header   >> Mention host header for api endpoint
  service_info              >> The configuration of service
  health_check              >> Health Check Config for the service
  EOF
  type = map(object({
    is_attach_service_with_lb = bool
    service_alb_host_header   = string
    alb_paths                 = list(string)
    alb_priority              = string
    service_info = object({
      cpu_allocation = number
      mem_allocation = number
      containers_num = number
      port           = number
      image          = string
    })
    health_check = object({
      interval            = number
      path                = string
      timeout             = number
      healthy_threshold   = number
      unhealthy_threshold = number
      matcher             = string
    })
  }))
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
  description = ""
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
