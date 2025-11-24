variable "project_name" {
  description = "The name used as a prefix for edge resources."
  type        = string
}

variable "domain_name" {
  description = "The root domain name (e.g., example.com) for Route 53 and ACM."
  type        = string
}