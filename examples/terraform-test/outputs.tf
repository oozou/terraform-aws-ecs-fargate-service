# VPC outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

# ECS Cluster outputs
output "ecs_cluster_name" {
  description = "ECS Cluster name"
  value       = module.fargate_cluster.ecs_cluster_name
}

output "ecs_cluster_arn" {
  description = "ECS Cluster ARN"
  value       = module.fargate_cluster.ecs_cluster_arn
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.fargate_cluster.alb_dns_name
}

output "alb_arn" {
  description = "ALB ARN"
  value       = module.fargate_cluster.alb_arn
}

output "alb_listener_http_arn" {
  description = "ALB HTTP listener ARN"
  value       = module.fargate_cluster.alb_listener_http_arn
}

# ECS Service outputs
output "service_name" {
  description = "ECS Service name"
  value       = module.api_service.service_name
}

output "service_arn" {
  description = "ECS Service ARN"
  value       = module.api_service.service_arn
}

output "task_definition_arn" {
  description = "ECS Task Definition ARN"
  value       = module.api_service.task_definition_arn
}

output "target_group_arn" {
  description = "Target Group ARN"
  value       = module.api_service.target_group_arn
}

output "target_group_id" {
  description = "Target Group ID"
  value       = module.api_service.target_group_id
}

output "task_role_arn" {
  description = "ECS Task role ARN"
  value       = module.api_service.task_role_arn
}

output "task_execution_role_arn" {
  description = "ECS Task execution role ARN"
  value       = module.api_service.task_execution_role_arn
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name"
  value       = module.api_service.cloudwatch_log_group_name
}
