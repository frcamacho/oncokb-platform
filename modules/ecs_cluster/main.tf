# ECS Cluster with Mixed Architecture (x86_64 + ARM64)
# Supports both Intel (x86) and Graviton (ARM) instances in the same cluster

# Get latest ECS-optimized AMIs
data "aws_ssm_parameter" "ecs_ami_x86" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

data "aws_ssm_parameter" "ecs_ami_arm" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/arm64/recommended/image_id"
}

# ECS Cluster
resource "aws_ecs_cluster" "this" {
  name = "${var.environment}-oncokb-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "${var.environment}-oncokb-cluster"
    Environment = var.environment
  }
}

# Launch Template for x86_64 instances
resource "aws_launch_template" "ecs_x86" {
  name_prefix   = "${var.environment}-oncokb-ecs-x86-"
  image_id      = data.aws_ssm_parameter.ecs_ami_x86.value
  instance_type = var.instance_type_x86

  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  vpc_security_group_ids = [var.ecs_security_group_id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${var.environment}-oncokb-cluster >> /etc/ecs/ecs.config
    echo ECS_ENABLE_TASK_IAM_ROLE=true >> /etc/ecs/ecs.config
    echo ECS_AWSVPC_BLOCK_IMDS=true >> /etc/ecs/ecs.config
  EOF
  )

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 60
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name         = "${var.environment}-oncokb-ecs-x86"
      Environment  = var.environment
      Architecture = "x86_64"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Launch Template for ARM64 instances
resource "aws_launch_template" "ecs_arm" {
  name_prefix   = "${var.environment}-oncokb-ecs-arm-"
  image_id      = data.aws_ssm_parameter.ecs_ami_arm.value
  instance_type = var.instance_type_arm

  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  vpc_security_group_ids = [var.ecs_security_group_id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${var.environment}-oncokb-cluster >> /etc/ecs/ecs.config
    echo ECS_ENABLE_TASK_IAM_ROLE=true >> /etc/ecs/ecs.config
    echo ECS_AWSVPC_BLOCK_IMDS=true >> /etc/ecs/ecs.config
  EOF
  )

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 60
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name         = "${var.environment}-oncokb-ecs-arm"
      Environment  = var.environment
      Architecture = "arm64"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group for x86_64 instances
resource "aws_autoscaling_group" "ecs_x86" {
  name                = "${var.environment}-oncokb-ecs-asg-x86"
  vpc_zone_identifier = var.private_subnet_ids
  min_size            = var.asg_x86_min_size
  max_size            = var.asg_x86_max_size
  desired_capacity    = var.asg_x86_desired_capacity

  launch_template {
    id      = aws_launch_template.ecs_x86.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300
  protect_from_scale_in     = true

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${var.environment}-oncokb-ecs-x86"
    propagate_at_launch = true
  }

  tag {
    key                 = "Architecture"
    value               = "x86_64"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# Auto Scaling Group for ARM64 instances
resource "aws_autoscaling_group" "ecs_arm" {
  name                = "${var.environment}-oncokb-ecs-asg-arm"
  vpc_zone_identifier = var.private_subnet_ids
  min_size            = var.asg_arm_min_size
  max_size            = var.asg_arm_max_size
  desired_capacity    = var.asg_arm_desired_capacity

  launch_template {
    id      = aws_launch_template.ecs_arm.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300
  protect_from_scale_in     = true

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${var.environment}-oncokb-ecs-arm"
    propagate_at_launch = true
  }

  tag {
    key                 = "Architecture"
    value               = "arm64"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# ECS Capacity Provider for x86_64
resource "aws_ecs_capacity_provider" "x86" {
  name = "${var.environment}-oncokb-x86-cp"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs_x86.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      maximum_scaling_step_size = 2
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 80
    }
  }
}

# ECS Capacity Provider for ARM64
resource "aws_ecs_capacity_provider" "arm" {
  name = "${var.environment}-oncokb-arm-cp"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs_arm.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      maximum_scaling_step_size = 2
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 80
    }
  }
}

# Attach both capacity providers to cluster
resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name
  capacity_providers = [
    aws_ecs_capacity_provider.x86.name,
    aws_ecs_capacity_provider.arm.name
  ]

  # Default to x86 but both are available
  default_capacity_provider_strategy {
    base              = 1
    weight            = 50
    capacity_provider = aws_ecs_capacity_provider.x86.name
  }

  default_capacity_provider_strategy {
    weight            = 50
    capacity_provider = aws_ecs_capacity_provider.arm.name
  }
}
