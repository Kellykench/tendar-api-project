output "cache_endpoint" {
  description = "The primary connection endpoint for the Redis ElastiCache cluster."
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "cache_sg_id" {
  description = "The Security Group ID of the Redis instance."
  value       = aws_security_group.cache_sg.id
}