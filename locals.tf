data "aws_caller_identity" "active" {
  provider = aws.service
}

data "aws_region" "active" {
  provider = aws.service
}

locals {
  log_group_name = "${local.service_name}-service-log-group"

  ecs_cluster_arn        = "arn:aws:ecs:${data.aws_region.active.name}:${data.aws_caller_identity.active.account_id}:cluster/${var.ecs_cluster_name}"
  apm_name               = "xray-apm-sidecar"
  enable_alb_host_header = var.alb_host_header != null ? true : false

  task_role_arn       = !var.is_create_iam_role && var.exists_task_role_arn != null  ? var.exists_task_role_arn : aws_iam_role.task_role[0].arn
  task_role_id        = split("/",local.task_role_arn)[1]

  task_execution_role_arn       = !var.is_create_iam_role && var.exists_task_execution_role_arn != null  ? var.exists_task_execution_role_arn : aws_iam_role.task_execution[0].arn
  task_execution_role_id        = split("/",local.task_execution_role_arn)[1]

}

locals {

  /* -------------------------------------------------------------------------- */
  /*                                   SECRET                                   */
  /* -------------------------------------------------------------------------- */

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

  /* -------------------------------------------------------------------------- */
  /*                                 JSON SECRET                                */
  /* -------------------------------------------------------------------------- */

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

locals {
  is_apm_enabled = signum(length(trimspace(var.apm_sidecar_ecr_url))) == 1
}
