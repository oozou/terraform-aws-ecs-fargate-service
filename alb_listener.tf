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

  provider = aws.service
}
