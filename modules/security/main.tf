# Declare module input variables
variable "project_name" { type = string }

# Define local tags for all resources
locals {
  tags = {
    Name    = var.project_name
    Project = "Tendar"
    Tier    = "Security"
  }
  # ECS Task Role Policy Document
  ecs_task_assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

# 1. IAM Role for ECS Task Execution (Allows ECS to pull images and publish logs)
resource "aws_iam_role" "ecs_task_execution" {
  name               = "${var.project_name}-ecs-exec-role"
  assume_role_policy = local.ecs_task_assume_role_policy
  tags               = local.tags
}

# Attach the managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_exec_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 2. IAM Role for ECS Tasks (Allows application code to interact with AWS services, e.g., DynamoDB, S3)
resource "aws_iam_role" "ecs_task" {
  name               = "${var.project_name}-ecs-task-role"
  assume_role_policy = local.ecs_task_assume_role_policy
  tags               = local.tags
}

# Attach a placeholder read-only policy. Best practice is to attach a Least Privilege policy here later.
resource "aws_iam_role_policy_attachment" "ecs_task_readonly_policy" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess" # REPLACE THIS WITH A CUSTOM, SCOPED POLICY LATER
}

# 3. AWS Secrets Manager Secret (Stores sensitive data like database credentials)
# Using 'random_string' to generate a secure secret value for a DB password.
resource "random_string" "db_password" {
  length  = 20
  special = false
  upper   = true
  lower   = true
  numeric = true
}

resource "aws_secretsmanager_secret" "database_creds" {
  name                    = "${var.project_name}/database/credentials"
  description             = "Database credentials for the Tendar application."
  recovery_window_in_days = 7 # Best practice for production secrets
  tags                    = local.tags
}

resource "aws_secretsmanager_secret_version" "database_creds_version" {
  secret_id = aws_secretsmanager_secret.database_creds.id
  secret_string = jsonencode({
    username = "tendar_app_user"
    password = random_string.db_password.result
    # You would also store DB endpoint, port, etc., here
  })
}

# 4. IAM Policy to Grant Secrets Manager Access to the Task Execution Role
resource "aws_iam_policy" "ecs_secret_access" {
  name        = "${var.project_name}-ecs-secret-access-policy"
  description = "Allows ECS Task Execution Role to read the application database secret."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
        ]
        Resource = [
          # Grant permission only to the specific database secret
          aws_secretsmanager_secret.database_creds.arn,
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
        ]
        Resource = [
          # Grant permission to the default AWS KMS key for Secrets Manager
          # This ARN specifically targets the AWS-managed key for Secrets Manager (alias/aws/secretsmanager)
          "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*",
          
          # This ARN is a best practice inclusion if you are using the default KMS key
          # It refers to the secret's encrypted data resource
          aws_secretsmanager_secret.database_creds.arn,
        ]
      },
    ]
  })
}

# 5. Attachment to the ECS Task Execution Role
resource "aws_iam_role_policy_attachment" "ecs_task_exec_secret_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = aws_iam_policy.ecs_secret_access.arn
}

# 6. Data sources needed for the KMS ARN
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# OUTPUTS (Used by the root main.tf and ECS module)
output "ecs_task_execution_role_arn" {
  value = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  value = aws_iam_role.ecs_task.arn
}

output "database_secret_arn" {
  value = aws_secretsmanager_secret.database_creds.arn
}

# New Output for the raw database password
output "db_password_string" {
  description = "The generated random database password string."
  value       = random_string.db_password.result
  sensitive   = true # IMPORTANT: Mark as sensitive
}