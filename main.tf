terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
}

#locals {
 # availability_zones = ["${var.aws_region}a", "${var.aws_region}b"]
#}

#locals {
#  vpcs_to_log = [
#    aws_vpc.vpc.id,
#    data.aws_vpc.default.id
#    ]
#  }

# CloudWatch Log Group
#resource "aws_cloudwatch_log_group" "vpc_logs" {
#  name              = "/vpc/flow-logs"
#  retention_in_days = 14
#}

# IAM Role for VPC Flow Logs
#resource "aws_iam_role" "vpc_flow_logs_role" {
#  name = "vpc-flow-logs-role"

#  assume_role_policy = jsonencode({
#    Version = "2012-10-17",
#    Statement = [{
#      Action    = "sts:AssumeRole",
#      Effect    = "Allow",
#      Principal = {
#        Service = "vpc-flow-logs.amazonaws.com"
#      }
#    }]
#  })
#}

# IAM Policy Attachment
#resource "aws_iam_role_policy" "vpc_flow_logs_policy" {
#  name = "vpc-flow-logs-policy"
#  role = aws_iam_role.vpc_flow_logs_role.id

#  policy = jsonencode({
#    Version = "2012-10-17",
#    Statement = [{
#      Effect   = "Allow",
#      Action   = [
#        "logs:CreateLogStream",
#        "logs:PutLogEvents"
#      ],
#      Resource = "*"
#    }]
#  })
#}

# VPC Flow Log (replace with your VPC ID) //COMMENT AND UNCOMMENT THIS PART ONLY
#resource "aws_flow_log" "vpc_flow" {
#  for_each             = toset(local.vpcs_to_log)

#  log_destination_type = "cloud-watch-logs"
  #log_group_name       = aws_cloudwatch_log_group.vpc_logs.name
#  log_destination       = aws_cloudwatch_log_group.vpc_logs.arn
#  iam_role_arn         = aws_iam_role.vpc_flow_logs_role.arn
#  traffic_type         = "ALL"
  #vpc_id               = var.vpc_id
#  vpc_id               = each.key
#}


# VPC
#data "aws_vpc" "default" {
#  default = true
#}

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.environment}-vpc"
    #Environment = var.environment
  }
}


# Public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  #count                   = length(var.public_subnets_cidr)
  #cidr_block              = element(var.public_subnets_cidr, count.index)
  cidr_block              = var.public_subnets_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.environment}-${var.aws_region}a}-public-subnet"
    Environment = "${var.environment}"
  }
}

# Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  #count                   = length(var.private_subnets_cidr)
  #cidr_block              = element(var.private_subnets_cidr, count.index)
  cidr_block              = var.private_subnets_cidr
  #availability_zone       = element(local.availability_zones, count.index)
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.environment}-${var.aws_region}a}-private-subnet"
    Environment = "${var.environment}"
  }
}

#Internet gateway
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name"        = "${var.environment}-igw"
    "Environment" = var.environment
  }
}

# Elastic-IP (eip) for NAT
resource "aws_eip" "nat_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.ig]
}

# NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  #subnet_id     = element(aws_subnet.public_subnet.*.id, 0)
  subnet_id     = aws_subnet.public_subnet.id
  tags = {
    Name        = "nat-gateway-${var.environment}"
    Environment = "${var.environment}"
  }
}

# Routing tables to route traffic for Private Subnet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name        = "${var.environment}-private-route-table"
    Environment = "${var.environment}"
  }
}

# Routing tables to route traffic for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.environment}-public-route-table"
    Environment = "${var.environment}"
  }
}

# Route for Internet Gateway
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig.id
}

# Route for NAT Gateway
resource "aws_route" "private_internet_gateway" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.nat.id
}

# Route table associations for both Public & Private Subnets
resource "aws_route_table_association" "public" {
  #count          = var.public_subnets_cidr
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  #count          = length(var.private_subnets_cidr
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private.id
}
