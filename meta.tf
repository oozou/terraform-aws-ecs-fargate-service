data "aws_caller_identity" "active" {
  provider = aws.service
}

data "aws_region" "active" {
  provider = aws.service
}

locals {
  log_group_name = "${local.service_name}-service-log-group"

  ecs_cluster_arn = "arn:aws:ecs:${data.aws_region.active.name}:${data.aws_caller_identity.active.account_id}:cluster/${var.ecs_cluster_name}"
  apm_name        = "xray-apm-sidecar"
  enable_alb_host_header = var.alb_host_header != null ? true : false

}

locals {
  # Create secret arn collection for granting "secretmanager:GetSecret" permission
  secret_manager_arns = [for secret in aws_secretsmanager_secret.service_secrets : secret.arn]

  # Get Secret Name Arrays
  secret_names = keys(var.secrets)

  # Create a secret map { secret_name : secret_arn } using ZipMap Function for iteration
  secrets_name_arn_map = zipmap(local.secret_names, local.secret_manager_arns)
  #
  # Create secrets format for Task Definition 
  #     map("name", upper(secret_key), "valueFrom", secret_arn)
  secrets_task_definition = [for secret_key, secret_arn in local.secrets_name_arn_map :
    tomap({
      name = upper(secret_key)
      valueFrom = secret_arn
    })
  ]
}

locals {
  is_apm_enabled = signum(length(trimspace(var.apm_sidecar_ecr_url))) == 1
}
