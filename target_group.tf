resource "aws_lb_target_group" "main" {
  count       = var.attach_lb ? 1 : 0
  name        = substr(local.service_name, 0, min(32, length(local.service_name)))
  port        = var.service_port
  protocol    = var.service_port == 443 ? "HTTPS" : "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    interval            = var.health_check.interval
    path                = var.health_check.path
    timeout             = var.health_check.timeout
    healthy_threshold   = var.health_check.healthy_threshold
    unhealthy_threshold = var.health_check.unhealthy_threshold
    matcher             = var.health_check.matcher
  }

  tags = merge({
    Name = "${local.service_name}-tg"
  }, local.tags)

  provider = aws.service
}

