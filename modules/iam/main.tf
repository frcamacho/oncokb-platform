# IAM roles for ECS Fargate deployment
# - task_execution_role: Used by ECS agent to pull images and write logs
# - task_role: Used by application containers

data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ── ECS Task Execution Role ───────────────────────────────────────────────────
resource "aws_iam_role" "task_execution" {
  name               = "${var.environment}-oncokb-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow task execution role to read Secrets Manager
data "aws_iam_policy_document" "task_execution_secrets" {
  statement {
    sid    = "ReadSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = ["arn:aws:secretsmanager:${var.aws_region}:*:secret:oncokb/${var.environment}/*"]
  }
}

resource "aws_iam_role_policy" "task_execution_secrets" {
  name   = "${var.environment}-task-execution-secrets"
  role   = aws_iam_role.task_execution.id
  policy = data.aws_iam_policy_document.task_execution_secrets.json
}

# ECS Task Role (application permissions)
resource "aws_iam_role" "task" {
  name               = "${var.environment}-oncokb-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

# Allow tasks to write CloudWatch logs
data "aws_iam_policy_document" "task_logs" {
  statement {
    sid    = "WriteLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:${var.aws_region}:*:log-group:/ecs/oncokb/${var.environment}/*"]
  }
}

resource "aws_iam_role_policy" "task_logs" {
  name   = "${var.environment}-task-logs"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_logs.json
}

# Allow tasks to use ECS Exec (SSM Session Manager)
data "aws_iam_policy_document" "task_ssm" {
  statement {
    sid    = "ECSExec"
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "task_ssm" {
  name   = "${var.environment}-task-ssm"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_ssm.json
}

# Allow tasks to access EFS
data "aws_iam_policy_document" "task_efs" {
  statement {
    sid    = "EFSAccess"
    effect = "Allow"
    actions = [
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite",
      "elasticfilesystem:DescribeMountTargets",
    ]
    resources = [var.efs_filesystem_arn]
  }
}

resource "aws_iam_role_policy" "task_efs" {
  name   = "${var.environment}-task-efs"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_efs.json
}
