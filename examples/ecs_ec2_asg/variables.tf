variable "generics_info" {
  description = "Generic infomation"
  type = object({
    region      = string
    prefix      = string
    environment = string
    name        = string
    custom_tags = map(any)
  })
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
