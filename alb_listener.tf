resource "aws_lb_listener_rule" "main" {
  count        = var.attach_lb ? 1 : 0
  listener_arn = var.alb_listener_arn
  priority     = var.alb_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[0].arn
  }

  condition {
    path_pattern {
      values = [var.alb_path == "" ? "*" : var.alb_path]
    }
  }

  dynamic "condition" {
    for_each = local.enable_alb_host_header ? [true] : []
    content {
      host_header {
        values = [var.alb_host_header]
      }
    }
  }

  dynamic "condition" {
    for_each = var.custom_header_token == "" ? [] : [true]
    content {
      http_header {
        http_header_name = "custom-header-token" # Match value within cloudfront module
        values           = [var.custom_header_token]
      }
    }
  }

  provider = aws.service
}
