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
