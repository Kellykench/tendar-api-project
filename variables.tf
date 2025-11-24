variable "vpc_id" {
  description = "The ID of the deployed VPC."
  type        = string
}

variable "private_subnet_ids" {
  description = "A list of private subnet IDs for EKS/Fargate deployment."
  type        = list(string)
}