# Declare module input variables
variable "project_name" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "public_subnet_ids" { type = list(string) }
variable "ecs_task_execution_role_arn" { type = string }
variable "ecs_task_role_arn" { type = string }
variable "database_secret_arn" { type = string }

# Define local tags for all resources
locals {
  tags = {
    Name    = var.project_name
    Project = "Tendar"
    Tier    = "Compute"
  }
  container_port = 80
  app_image      = "nginx:latest" # Placeholder: Replace with your Tendar ECR image URI
}

# Data source for the default VPC security group (to allow ingress/egress for the ALB/ECS)
data "aws_vpc" "default" {
  id = var.vpc_id
}

# 1. ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled" # Recommended best practice for monitoring
  }
  tags = local.tags
}

# 2. Security Group for the ALB (Allows public access on port 80/443)
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Controls ingress to the Application Load Balancer"
  vpc_id      = var.vpc_id

  # Ingress rule: Allow HTTP traffic from anywhere
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress rule: Allow all outbound traffic (ALB needs to talk to the Fargate tasks)
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.tags, { Name = "${var.project_name}-alb-sg" })
}

# 3. Security Group for ECS Tasks (Allows traffic only from the ALB)
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks-sg"
  description = "Controls ingress/egress for Fargate Tasks"
  vpc_id      = var.vpc_id

  # Ingress rule: Allow traffic from the ALB Security Group on the container port
  ingress {
    protocol        = "tcp"
    from_port       = local.container_port
    to_port         = local.container_port
    security_groups = [aws_security_group.alb.id]
  }

  # Egress rule: Allow all outbound traffic (tasks need access to NAT Gateway for updates, etc.)
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.tags, { Name = "${var.project_name}-ecs-tasks-sg" })
}

# 4. Application Load Balancer (ALB)
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids # ALB lives in the public subnets
  tags               = local.tags
}

# 5. ALB Target Group (Routes traffic to ECS tasks)
resource "aws_lb_target_group" "main" {
  name        = "${var.project_name}-tg"
  port        = local.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Required for Fargate

  health_check {
    path                = "/" # Default health check path
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags = local.tags
}

# 6. ALB Listener (Listens on port 80 and forwards to the Target Group)
resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.main.arn
    port     = "80"
    protocol = "HTTP"

    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.main.arn
        
    }
}

# 7. ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256" # 0.25 vCPU
  memory                   = "512" # 0.5 GB RAM
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  # Container Definitions: Defines the application container and logging
  container_definitions = jsonencode([
    {
      name      = var.project_name
      image     = local.app_image
      essential = true
      portMappings = [{
        containerPort = local.container_port
        hostPort      = local.container_port
      }]
      # Securely pass database credentials via Secrets Manager
      secrets = [{
        name      = "DB_PASSWORD"
        valueFrom = var.database_secret_arn
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project_name}-log-group"
          "awslogs-region"        = "us-west-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
  tags = local.tags
}

# 8. ECS Service (Deploys and maintains the desired task count)
resource "aws_ecs_service" "main" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2 # High Availability across 2 AZs
  launch_type     = "FARGATE"
  
  # Deploy in the Private Subnets
  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

    load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = var.project_name
    container_port   = local.container_port
   }
  
  # Ensure the service waits for the ALB to be ready
   depends_on = [aws_lb_listener.http, aws_lb_target_group.main]

   tags = local.tags
}

# 9. CloudWatch Log Group for ECS Tasks
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.project_name}-log-group"
  retention_in_days = 90
  tags              = local.tags
}

# OUTPUTS
output "alb_dns_name" {
  value = aws_lb.main.dns_name
}