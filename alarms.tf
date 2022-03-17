# module "sns" {
#   source = "git@gitlab.com:mango-engineering/mango-infra-components/terraform-aws-sns-notifications?ref=v4.1.0"

#   base_name   = local.service_name
#   use_case    = "fargate"
#   email_ids   = var.email_ids
#   custom_tags = var.custom_tags

#   providers = {
#     aws = aws.service
#   }
# }

# resource "aws_cloudwatch_metric_alarm" "public_service_cpu_utilization_too_high" {
#   alarm_name          = "${local.service_name}-fargate-CPUUtilization"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = "1"
#   metric_name         = "CPUUtilization"
#   namespace           = "AWS/ECS"
#   period              = "300"
#   statistic           = "Average"
#   threshold           = "80"
#   alarm_actions       = [module.sns.topic_arn]
#   alarm_description   = "Average container CPU utilization over last 5 minutes >80%"
#   count               = var.attach_lb ? 1 : 0

#   # Either use depends_on = ["aws_ecs_service.public_service"] explicitly or extract the name after creation of the service.
#   dimensions = {
#     ClusterName = var.ecs_cluster_name
#     ServiceName = aws_ecs_service.public_service[0].name
#   }

#   tags = merge({
#     Name = "${local.service_name}-fargate-cluster"
#   }, var.custom_tags)

#   provider = aws.service
# }

# resource "aws_cloudwatch_metric_alarm" "public_service_memory_utilization_too_high" {
#   alarm_name          = "${local.service_name}-fargate-MemoryUtilization"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = "1"
#   metric_name         = "MemoryUtilization"
#   namespace           = "AWS/ECS"
#   period              = "300"
#   statistic           = "Average"
#   threshold           = "80"
#   alarm_actions       = [module.sns.topic_arn]
#   alarm_description   = "Average container memory utilization over last 5 minutes >80%"
#   count               = var.attach_lb ? 1 : 0

#   # Either use depends_on = ["aws_ecs_service.public_service"] explicitly or extract the name after creation of the service.
#   dimensions = {
#     ClusterName = var.ecs_cluster_name
#     ServiceName = aws_ecs_service.public_service[0].name
#   }

#   tags = merge({
#     Name = "${local.service_name}-fargate-cluster"
#   }, var.custom_tags)

#   provider = aws.service
# }

# resource "aws_cloudwatch_metric_alarm" "private_service_cpu_utilization_too_high" {
#   alarm_name          = "${local.service_name}-fargate-CPUUtilization"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = "1"
#   metric_name         = "CPUUtilization"
#   namespace           = "AWS/ECS"
#   period              = "300"
#   statistic           = "Average"
#   threshold           = "80"
#   alarm_actions       = [module.sns.topic_arn]
#   alarm_description   = "Average container CPU utilization over last 5 minutes >80%"
#   count               = var.attach_lb ? 0 : 1

#   # Either use depends_on = ["aws_ecs_service.private_service"] explicitly or extract the name after creation of the service.
#   dimensions = {
#     ClusterName = var.ecs_cluster_name
#     ServiceName = aws_ecs_service.private_service[0].name
#   }

#   tags = merge({
#     Name = "${local.service_name}-fargate-cluster"
#   }, var.custom_tags)

#   provider = aws.service
# }

# resource "aws_cloudwatch_metric_alarm" "private_service_memory_utilization_too_high" {
#   alarm_name          = "${local.service_name}-fargate-MemoryUtilization"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = "1"
#   metric_name         = "MemoryUtilization"
#   namespace           = "AWS/ECS"
#   period              = "300"
#   statistic           = "Average"
#   threshold           = "80"
#   alarm_actions       = [module.sns.topic_arn]
#   alarm_description   = "Average container memory utilization over last 5 minutes >80%"
#   count               = var.attach_lb ? 0 : 1

#   # Either use depends_on = ["aws_ecs_service.private_service"] explicitly or extract the name after creation of the service.
#   dimensions = {
#     ClusterName = var.ecs_cluster_name
#     ServiceName = aws_ecs_service.private_service[0].name
#   }

#   tags = merge({
#     Name = "${local.service_name}-fargate-cluster"
#   }, var.custom_tags)

#   provider = aws.service
# }
