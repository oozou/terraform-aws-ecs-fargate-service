# Create the logs
resource "aws_cloudwatch_log_group" "main" {
  name              = "${var.service_name}-service-log-group"
  retention_in_days = 30

  tags = merge({
    Name = "${var.service_name}-service-log-group"
  }, var.custom_tags)

  provider = aws.service
}

