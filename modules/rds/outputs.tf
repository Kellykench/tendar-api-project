output "db_endpoint" {
  description = "The connection endpoint for the PostgreSQL database."
  value       = aws_db_instance.postgres.endpoint
}

output "db_sg_id" {
  description = "The Security Group ID of the RDS instance."
  value       = aws_security_group.db_sg.id
}