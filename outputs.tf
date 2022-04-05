output "task_role_id" {
  description = "ECS Task role ID"
  value       = local.task_role_id
}

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

output "secret_json_arn" {
  description = "List of ARNs of the SecretsManager json secrets"
  value       = local.secret_manager_json_arn
}

output "secret_arns" {
  description = "List of ARNs of the SecretsManager secrets"
  value       = local.secret_manager_arns
}
