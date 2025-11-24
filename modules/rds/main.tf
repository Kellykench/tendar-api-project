# 1. RDS Security Group (Allows EKS traffic only)
resource "aws_security_group" "db_sg" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow EKS cluster to connect to PostgreSQL"
  vpc_id      = var.vpc_id

  # Ingress: Allow PostgreSQL traffic (port 5432) from the EKS Security Group
  ingress {
    protocol        = "tcp"
    from_port       = 5432
    to_port         = 5432
    security_groups = [var.eks_sg_id] # Critical: Traffic only allowed from EKS
  }

  # Egress: Allows all outbound traffic for updates, etc.
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# 2. RDS Subnet Group (Required to place RDS instances in the VPC's private subnets)
resource "aws_db_subnet_group" "default" {
  subnet_ids = var.private_subnet_ids
  name       = "${var.project_name}-rds-subnet-group"

  tags = {
    Name = "${var.project_name}-rds-subnet-group"
  }
}

# 3. PostgreSQL Multi-AZ Instance
resource "aws_db_instance" "postgres" {
  identifier           = "${var.project_name}-db"
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "postgres"
  engine_version       = "14"
  instance_class       = "db.t3.micro"
  db_name              = var.project_name # Database name
  username             = var.db_username
  password             = var.db_password
  parameter_group_name = "default.postgres14"
  skip_final_snapshot  = true
  multi_az             = false # Crucial for Multi-AZ High Availability
  publicly_accessible  = false # CRITICAL: Keep database private
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name = aws_db_subnet_group.default.name
}