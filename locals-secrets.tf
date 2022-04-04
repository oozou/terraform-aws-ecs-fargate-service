/* -------------------------------------------------------------------------- */
/*                                   SECRET                                   */
/* -------------------------------------------------------------------------- */
locals {
  # Create secret arn collection for granting "secretmanager:GetSecret" permission
  secret_manager_arns = [for secret in aws_secretsmanager_secret.service_secrets : secret.arn]

  # Get Secret Name Arrays
  secret_names = keys(var.secrets)

  # Create a secret map { secret_name : secret_arn } using ZipMap Function for iteration
  secrets_name_arn_map = zipmap(local.secret_names, local.secret_manager_arns)
  #
  # Create secrets format for Task Definition
  secrets_task_unique_definition = [for secret_key, secret_arn in local.secrets_name_arn_map :
    tomap({
      name      = upper(secret_key)
      valueFrom = secret_arn
    })
  ]
}

/* -------------------------------------------------------------------------- */
/*                                 JSON SECRET                                */
/* -------------------------------------------------------------------------- */
locals {
  # Get secret arn for granting  "secretmanager:GetSecret" permission
  secret_manager_json_arns = aws_secretsmanager_secret.service_json_secrets.arn

  # Map JSON Secret to Secret Arrays
  secrets_name_json_arn_map = { "JSON_SECRET" : local.secret_manager_json_arns }

  # Create secrets JSON format for Task Definition
  secrets_json_task_definition = [for secret_key, secret_arn in local.secrets_name_json_arn_map :
    tomap({
      name      = upper(secret_key)
      valueFrom = secret_arn
    })
  ]
  # Concat Secret and JSON Secret to the one list.
  secrets_task_definition = concat(local.secrets_task_unique_definition, local.secrets_json_task_definition)
}
