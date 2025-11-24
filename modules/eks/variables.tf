variable "project_name" {
  description = "Name used as a prefix for EKS resources."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the EKS cluster will be deployed."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the EKS worker nodes."
  type        = list(string)
}

variable "kubernetes_version" {
  description = "The desired Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.28" 
}