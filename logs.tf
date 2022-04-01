# # Create the logs
# resource "aws_cloudwatch_log_group" "main" {
#   name              = "${local.service_name}-service-log-group"
#   retention_in_days = 30

#   tags = merge({
#     Name = "${local.service_name}-service-log-group"
#   }, local.tags)

#   provider = aws.service
# }
