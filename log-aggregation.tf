# # module "log_aggregation" {
# #   source = "git@gitlab.com:mango-engineering/mango-infra-components/terraform-aws-cloudwatch-aggregation?ref=v5.1.0"

# #   # service_name is composed of "${var.application_name}-${var.service_name}" which makes the module name unique across the estate
# #   module_name = var.service_name
# #   custom_tags = var.custom_tags

# #   log_group_name       = local.log_group_name
# #   logs_type            = "SERVICE"
# #   source_account_alias = var.account_alias
# #   s3                   = var.log_aggregation_s3

# #   providers = {
# #     aws.source  = aws.service
# #     aws.logging = aws.logging
# #   }
# # }
