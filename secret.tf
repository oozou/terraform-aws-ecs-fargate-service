module "secret_kms_key" {
  source = "git@github.com:oozou/terraform-aws-kms-key.git?ref=v0.0.1"

  alias_name           = "${var.service_name}-service-secrets"
  append_random_suffix = true
  custom_tags          = var.custom_tags
  key_type             = "service"
  description          = "Secure Secrets Manager's service secrets for service ${var.service_name}"

  service_key_info = {
    # aws_service_names  = list(format("secretsmanager.%s.amazonaws.com", data.aws_region.active.name))
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

resource "aws_secretsmanager_secret" "service_secrets" {
  for_each = var.secrets

  name        = "${var.service_name}/${lower(each.key)}-${random_string.service_secret_random_suffix.result}"
  description = "Secret 'secret_${lower(each.key)}' for service ${var.service_name}"
  kms_key_id  = module.secret_kms_key.key_arn

  tags = merge({
    Name = "${var.service_name}/${each.key}"
  }, var.custom_tags)

  provider = aws.service
}

resource "aws_secretsmanager_secret_version" "service_secrets" {
  for_each      = var.secrets
  secret_id     = aws_secretsmanager_secret.service_secrets[each.key].id
  secret_string = each.value

  provider = aws.service
}

# We add a policy to the ECS Task Execution role so that ECS can pull secrets from SecretsManager and
# inject them as environment variables in the service
resource "aws_iam_role_policy" "task_execution_secrets" {
  for_each = var.secrets
  name     = "${var.service_name}-ecs-task-execution-secrets"
  role     = aws_iam_role.task_execution.id

  policy = <<EOF
{
    "Statement": [
      {
        "Effect": "Allow",
        "Action": ["secretsmanager:GetSecretValue"],
        "Resource": ${jsonencode(local.secret_manager_arns)}
      }
    ]
}
EOF

  provider = aws.service
}
