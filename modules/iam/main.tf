# IAM roles for ECS on Fargate deployment
# - task_execution_role: Used by ECS agent to pull images and write logs
# - task_role: Used by application containers

# NOTE: EC2 instance roles commented out as we're using Fargate
# If switching back to EC2, uncomment the EC2 instance role section below

# data "aws_iam_policy_document" "ec2_assume_role" {
#   statement {
#     actions = ["sts:AssumeRole"]
#     principals {
#       type        = "Service"
#       identifiers = ["ec2.amazonaws.com"]
#     }
#   }
# }

data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ── EC2 Instance Role (Not needed for Fargate) ───────────────────────────────
# Commented out as we're using Fargate. Uncomment if switching back to EC2.
#
# resource "aws_iam_role" "ecs_instance" {
#   name               = "${var.environment}-oncokb-ecs-instance-role"
#   assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
# }
#
# resource "aws_iam_role_policy_attachment" "ecs_instance_core" {
#   role       = aws_iam_role.ecs_instance.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
# }
#
# resource "aws_iam_role_policy_attachment" "ecs_instance_ssm" {
#   role       = aws_iam_role.ecs_instance.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# }
#
# data "aws_iam_policy_document" "ecs_instance_s3" {
#   statement {
#     sid    = "S3DeploymentAccess"
#     effect = "Allow"
#     actions = [
#       "s3:GetObject",
#       "s3:ListBucket",
#     ]
#     resources = [
#       "arn:aws:s3:::${var.deployment_bucket}",
#       "arn:aws:s3:::${var.deployment_bucket}/*",
#     ]
#   }
# }
#
# resource "aws_iam_role_policy" "ecs_instance_s3" {
#   name   = "${var.environment}-ecs-instance-s3"
#   role   = aws_iam_role.ecs_instance.id
#   policy = data.aws_iam_policy_document.ecs_instance_s3.json
# }
#
# resource "aws_iam_instance_profile" "ecs_instance" {
#   name = "${var.environment}-oncokb-ecs-instance-profile"
#   role = aws_iam_role.ecs_instance.name
# }

# ── ECS Task Execution Role ───────────────────────────────────────────────────
# ECS Task Execution Role
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
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "task_efs" {
  name   = "${var.environment}-task-efs"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_efs.json
}
