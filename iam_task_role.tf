resource "aws_iam_role" "task_role" {
  name               = "${local.service_name}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume_role_policy.json

  tags = merge({
    Name = "${local.service_name}-task-role"
  }, local.tags)

  provider = aws.service
}

data "aws_iam_policy_document" "task_assume_role_policy" {
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }

  provider = aws.service
}

resource "aws_iam_role_policy_attachment" "task_role" {
  for_each   = var.ecs_task_role_policy_arns
  role       = aws_iam_role.task_role.id
  policy_arn = each.value

  provider = aws.service
}

resource "aws_iam_role_policy_attachment" "task_role_xray" {
  role       = aws_iam_role.task_role.id
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"

  provider = aws.service
}

