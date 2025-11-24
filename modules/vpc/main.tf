# Declare module input variables from the root main.tf
variable "project_name" { type = string }
variable "vpc_cidr"     { type = string }
variable "azs"          { type = list(string) }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "enable_nat_gateway" { type = bool }
variable "single_nat_gateway" { type = bool }

# Define local tags for all resources
locals {
  tags = {
    Name    = var.project_name
    Project = "Tendar"
    Tier    = "Network"
  }
}

# 1. VPC Resource (The Network Container)
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, {
    Name = "${var.project_name}-vpc"
  })
}

# 2. Internet Gateway (For Public Subnets/Outbound traffic)
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = merge(local.tags, {
    Name = "${var.project_name}-igw"
  })
}

# 3. EIPs for NAT Gateways (One per AZ)
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? length(var.public_subnet_cidrs) : 0
  domain = "vpc"
  tags = merge(local.tags, {
    Name = "${var.project_name}-nat-eip-${count.index}"
  })
}

# 4. NAT Gateways (Enables Private Subnet Outbound Internet)
resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? length(var.public_subnet_cidrs) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags = merge(local.tags, {
    Name = "${var.project_name}-nat-gw-${count.index}"
  })
  depends_on = [aws_internet_gateway.main]
}

# 5. Public Subnets (For ALB and NAT Gateway)
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true # Required for NAT Gateway placement

  tags = merge(local.tags, {
    Name = "${var.project_name}-public-${var.azs[count.index]}"
  })
}

# 6. Private Subnets (For ECS Fargate Tasks)
resource "aws_subnet" "private" {
  count                   = length(var.private_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(local.tags, {
    Name = "${var.project_name}-private-${var.azs[count.index]}"
  })
}

# 7. Route Tables
# Public Route Table (Routes all traffic to the Internet Gateway)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = merge(local.tags, { Name = "${var.project_name}-public-rt" })
}

# Private Route Table (Routes all traffic to the NAT Gateway)
resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    # Route traffic to the NAT Gateway in the same AZ
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }
  tags = merge(local.tags, { Name = "${var.project_name}-private-rt-${count.index}" })
}

# 8. Route Table Associations
# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate Private Subnets with Private Route Tables
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# OUTPUTS (Used by the root main.tf)
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}