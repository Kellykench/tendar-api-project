## 1. AWS Provider and Backend Configuration
# ----------------------------------------
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

## 2. Provider Block
provider "aws" {
  region = "us-west-1"
}

# New provider alias for ACM/CloudFront resources
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

## 3. Variables for Environment Configuration
# ------------------------------------------
# Define environment-specific details
variable "project_name" {
  type    = string
  default = "tendar"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "domain_name" {
  description = "The domain name for the application (e.g., tendar.com)."
  type        = string
}

## 4. Core Network Module (VPC, Subnets, Gateways)
# ------------------------------------------------
# Provision the Virtual Private Cloud (VPC) that contains all resources.
# This module creates Public/Private subnets across multiple AZs and NAT Gateways.
module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr

  # Subnet configuration (VPC, AZ-1a, AZ-1b)
  azs                  = ["us-west-1a", "us-west-1c"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

  # Creates Internet Gateway and NAT Gateways (one per public subnet/AZ for high availability)
  enable_nat_gateway = true
  single_nat_gateway = false
}

## 5. Container Orchestration (ECS Fargate)
# ---------------------------------------------------------

# This module would provision the necessary ECS clusters and related security groups.

module "ecs_cluster" {
  source = "./modules/ecs_fargate"

  # 1. Project/Global Variable (Needed by almost all modules)
  project_name = var.project_name
  
  # 2. VPC Outputs (Inputs from the VPC module)
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  public_subnet_ids   = module.vpc.public_subnet_ids # <-- FIX: Missing Argument Added

  # 3. Security Outputs (Inputs from the Security module)
  ecs_task_execution_role_arn = module.security_identity.ecs_task_execution_role_arn # <-- FIX: Missing Argument Added
  ecs_task_role_arn           = module.security_identity.ecs_task_role_arn           # <-- FIX: Missing Argument Added
  database_secret_arn         = module.security_identity.database_secret_arn         # <-- FIX: Missing Argument Added
  
  # Further configuration for services (ALB, Task Definitions) would be inside this module
}

## 6. Security & Identity (IAM Roles, Secrets Manager)
# ----------------------------------------------------

module "security_identity" {
  source = "./modules/security"

  project_name = var.project_name 
  
  # The inputs below are no longer necessary here since the module now uses the outputs internally.
  # ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn 
  # secrets_ids = module.secrets_manager.secrets_ids
}

## 7. ECR Module
module "ecr" {
  source = "./modules/ecr" 
  
  # Pass variables required by the module
  project_name = var.project_name
}

## 8. EKS Module
module "eks" {
  source = "./modules/eks" 
  
  project_name       = var.project_name
  kubernetes_version = "1.28" # Explicitly define version

  # Pass VPC details from the existing VPC module or variables
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
}

## 9. RDS Module
module "rds" {
  source = "./modules/rds" 

  project_name       = var.project_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  
  # Database Credentials (use the secure secrets from your security module)
  db_username        = "tendaruser" # Replace with actual username if different
  db_password        = module.security_identity.db_password_string
  
  # Pass the EKS worker node Security Group ID
  eks_sg_id          = module.eks.worker_node_sg_id
}

## 10. ElastiCache Module
module "elasticache" {
  source = "./modules/elasticache" 
  
  project_name       = var.project_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  
  # Pass the EKS worker node Security Group ID
  eks_sg_id          = module.eks.worker_node_sg_id 
}

## 11. Edge Module (Route 53 & ACM)
module "edge" {
  source = "./modules/edge"
  
  project_name = var.project_name
  domain_name  = var.domain_name # Set this in your terraform.tfvars file
  
  # IMPORTANT: We need to pass the us-east-1 provider to the module
  providers = {
    aws = aws.us-east-1
  }
}

## 12. Output 
# -------------------------
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets" {
  value = module.vpc.private_subnet_ids
}

output "alb_dns_name" {
  value = module.ecs_cluster.alb_dns_name
}

output "name_servers" {
  description = "The Route 53 Name Servers required for domain delegation."
  value       = module.edge.name_servers
}