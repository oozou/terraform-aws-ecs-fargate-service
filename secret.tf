module "secret_kms_key" {
  source = "git@github.com:oozou/terraform-aws-kms-key.git?ref=v0.0.1"

  alias_name           = "${local.service_name}-service-secrets"
  append_random_suffix = true
  custom_tags          = local.tags
  key_type             = "service"
  description          = "Secure Secrets Manager's service secrets for service ${local.service_name}"

  service_key_info = {
    aws_service_names  = tolist([format("secretsmanager.%s.amazonaws.com", data.aws_region.active.name)])
    caller_account_ids = tolist([data.aws_caller_identity.active.account_id])
  }

  providers = {
    aws = aws.service
  }
}

# Append random string to SM Secret names because once we tear down the infra, the secret does not actually
# get deleted right away, which means that if we then try to recreate the infra, it'll fail as the
# secret name already exists.
resource "random_string" "service_secret_random_suffix" {
  length  = 6
  special = false
}

/* -------------------------------------------------------------------------- */
/*                                   SECRET                                   */
/* -------------------------------------------------------------------------- */

resource "aws_secretsmanager_secret" "service_secrets" {
  for_each = var.secrets

  name        = "${local.service_name}/${lower(each.key)}-${random_string.service_secret_random_suffix.result}"
  description = "Secret 'secret_${lower(each.key)}' for service ${local.service_name}"
  kms_key_id  = module.secret_kms_key.key_arn

  tags = merge({
    Name = "${local.service_name}/${each.key}"
  }, local.tags)

  provider = aws.service
}

resource "aws_secretsmanager_secret_version" "service_secrets" {
  for_each      = var.secrets
  secret_id     = aws_secretsmanager_secret.service_secrets[each.key].id
  secret_string = each.value

  provider = aws.service
}


/* -------------------------------------------------------------------------- */
/*                                 JSON SECRET                                */
/* -------------------------------------------------------------------------- */

resource "aws_secretsmanager_secret" "service_json_secrets" {
  name        = "${local.service_name}/${random_string.service_secret_random_suffix.result}"
  description = "Secret for service ${local.service_name}"
  kms_key_id  = module.secret_kms_key.key_arn

  tags = merge({
    Name = "${local.service_name}"
  }, local.tags)

  provider = aws.service
}

resource "aws_secretsmanager_secret_version" "service_json_secrets" {
  secret_id     = aws_secretsmanager_secret.service_json_secrets.id
  secret_string = jsonencode(var.json_secrets)

  provider = aws.service
}


# We add a policy to the ECS Task Execution role so that ECS can pull secrets from SecretsManager and
# inject them as environment variables in the service
resource "aws_iam_role_policy" "task_execution_secrets" {
  count = var.is_create_iam_role ? 1 : 0

  name = "${local.service_name}-ecs-task-execution-secrets"
  # role = aws_iam_role.task_execution.id ${jsonencode(local.secret_manager_json_arns)}
  role = local.task_execution_role_id

  policy = <<EOFsplit
{
    "Statement": [
      {
        "Effect": "Allow",
        "Action": ["secretsmanager:GetSecretValue"],
        "Resource": ${jsonencode(local.secret_manager_json_arns)}
      }
    ]
}
EOF

  provider = aws.service
}
