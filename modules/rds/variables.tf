variable "project_name" {
  description = "The name used as a prefix for RDS resources."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the RDS will be deployed."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the RDS subnet group."
  type        = list(string)
}

variable "db_username" {
  description = "Master username for the database."
  type        = string
}

variable "db_password" {
  description = "Master password for the database."
  type        = string
  sensitive   = true # Mark as sensitive to prevent logging
}

variable "eks_sg_id" {
  description = "The Security Group ID of the EKS worker nodes to allow database access."
  type        = string
}