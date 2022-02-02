resource "aws_iam_role" "task_execution" {
  name               = "${var.service_name}-ecs-task-execution"
  assume_role_policy = data.aws_iam_policy_document.task_execution_assume_role_policy.json

  tags = merge({
    Name = "${var.service_name}-task-execution"
  }, var.custom_tags)

  provider = aws.service
}

data "aws_iam_policy_document" "task_execution_assume_role_policy" {
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

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"

  provider = aws.service
}

