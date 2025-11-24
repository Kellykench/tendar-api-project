output "hosted_zone_id" {
  description = "The Route 53 Hosted Zone ID."
  value       = aws_route53_zone.primary.zone_id
}

output "name_servers" {
  description = "The list of Name Servers (NS) for the domain. REQUIRED for domain delegation!"
  value       = aws_route53_zone.primary.name_servers
}