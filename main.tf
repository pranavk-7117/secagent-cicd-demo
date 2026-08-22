# Secure Baseline Infrastructure + Remediated Web Tier
# Fixes applied via SecAgent Closed-Loop Remediation:
# 1. Scoped SSH port 22 to internal VPC CIDR (10.0.0.0/16) — eliminates T1190 public ingress
# 2. Scoped IAM role policy from wildcard (*) to least-privilege specific resource ARNs — eliminates T1078.004
# 3. Encrypted RDS PostgreSQL Database with public access disabled

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "production_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "production-vpc"
    Environment = "production"
  }
}

resource "aws_security_group" "public_web_sg" {
  name        = "public-web-security-group"
  description = "Remediated security group with restricted SSH"
  vpc_id      = aws_vpc.production_vpc.id

  ingress {
    description = "SSH from internal VPC only (SecAgent Remediated)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "HTTPS public web traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "production"
    Security    = "Remediated"
  }
}

resource "aws_iam_role" "wildcard_admin_role" {
  name = "production-admin-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "wildcard_admin_policy" {
  name = "wildcard-admin-policy"
  role = aws_iam_role.wildcard_admin_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["s3:GetObject", "s3:PutObject"]
      Effect   = "Allow"
      Resource = "arn:aws:s3:::production-app-data/*"
    }]
  })
}

resource "aws_iam_instance_profile" "web_admin_profile" {
  name = "web-admin-profile"
  role = aws_iam_role.wildcard_admin_role.name
}

resource "aws_instance" "exposed_web_server" {
  ami                  = "ami-0c55b159cbfafe1f0"
  instance_type        = "t3.micro"
  vpc_security_group_ids = [aws_security_group.public_web_sg.id]
  iam_instance_profile = aws_iam_instance_profile.web_admin_profile.name

  tags = {
    Name        = "production-web-server"
    Environment = "production"
  }
}

resource "aws_db_instance" "production_db" {
  allocated_storage   = 20
  engine              = "postgres"
  engine_version      = "15"
  instance_class      = "db.t3.micro"
  db_name             = "production_db"
  username            = "db_admin"
  password            = "VeryStrongPassword2026!"
  storage_encrypted   = true
  publicly_accessible = false
  skip_final_snapshot = true

  tags = {
    Name        = "production-database"
    Environment = "production"
  }
}
