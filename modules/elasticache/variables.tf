variable "project_name" {
  description = "The name used as a prefix for ElastiCache resources."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the Redis cluster will be deployed."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the ElastiCache subnet group."
  type        = list(string)
}

variable "eks_sg_id" {
  description = "The Security Group ID of the EKS worker nodes to allow cache access."
  type        = string
}