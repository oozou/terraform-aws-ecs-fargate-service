output "task_role_arn" {
  description = "ECS Task role ARN"
  value       = local.task_role_arn
}

output "task_execution_role_id" {
  description = "ECS Task execution role ID"
  value       = local.task_execution_role_id
}

output "task_execution_role_arn" {
  description = "ECS Task execution role ARN"
  value       = local.task_execution_role_arn
}

output "secret_arns" {
  description = "List of ARNs of the SecretsManager secrets"
  value       = try(aws_secretsmanager_secret.this[*].arn, "")
}

output "target_group_arn" {
  description = "id - ARN of the Target Group (matches arn)."
  value       = try(aws_lb_target_group.this[0].arn, "")
}

output "target_group_id" {
  description = "id - ARN of the Target Group (matches arn)."
  value       = try(aws_lb_target_group.this[0].id, "")
}

output "cloudwatch_log_group_name" {
  description = "The name of the log group"
  value       = try(aws_cloudwatch_log_group.this[0].name, null)
}

output "cloudwatch_log_group_arn" {
  description = "The name of the log group"
  value       = try(aws_cloudwatch_log_group.this[0].arn, null)
}

output "service_name" {
  description = "ECS Service name"
  value       = aws_ecs_service.this.name
}

output "service_arn" {
  description = "ECS Service ARN"
  value       = aws_ecs_service.this.id
}

output "task_definition_arn" {
  description = "ECS Task Definition ARN"
  value       = aws_ecs_task_definition.this.arn
}
