# output "task_role_id" {
#   description = "ECS Task role ID"
#   # value       = aws_iam_role.task_role[0].id
#   value       = local.task_role_id
# }

# output "task_role_arn" {
#   description = "ECS Task role ARN"
#   # value       = aws_iam_role.task_role[0].arn
#     value      = local.task_role_arn
# }

# output "task_execution_role_id" {
#   description = "ECS Task execution role ID"
#   # value       = aws_iam_role.task_execution.id
#   value       = local.task_execution_role_id
# }

# output "task_execution_role_arn" {
#   description = "ECS Task execution role ARN"
#   # value       = aws_iam_role.task_execution.arn
#   value       = local.task_execution_role_arn
# }

# output "secret_json_arns" {
#   description = "List of ARNs of the SecretsManager json secrets"
#   value       = local.secret_manager_json_arns
# }

# output "secret_arns" {
#   description = "List of ARNs of the SecretsManager secrets"
#   value       = local.secret_manager_arns
# }
