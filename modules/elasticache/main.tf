# modules/elasticache/main.tf

# 1. ElastiCache Security Group (Allows EKS traffic only)
resource "aws_security_group" "cache_sg" {
  name        = "${var.project_name}-cache-sg"
  description = "Allow EKS cluster to connect to Redis ElastiCache"
  vpc_id      = var.vpc_id

  # Ingress: Allow Redis traffic (port 6379) from the EKS Security Group
  ingress {
    protocol        = "tcp"
    from_port       = 6379
    to_port         = 6379
    security_groups = [var.eks_sg_id] # Critical: Traffic only allowed from EKS
  }

  # Egress: Allows all outbound traffic (for updates, etc.)
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-cache-sg"
  }
}

# 2. ElastiCache Subnet Group (Required to place Redis nodes in the private subnets)
resource "aws_elasticache_subnet_group" "default" {
  name       = "${var.project_name}-cache-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-cache-subnet-group"
  }
}

# 3. Redis ElastiCache Cluster
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.project_name}-redis"
  engine               = "redis"
  engine_version       = "6.x" # A commonly available version
  node_type            = "cache.t3.micro" # Free-tier compatible instance size
  num_cache_nodes      = 1 # Start with a single node
  parameter_group_name = "default.redis6.x"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.default.name
  security_group_ids   = [aws_security_group.cache_sg.id]

  tags = {
    Name = "${var.project_name}-redis"
  }
}