# Secure Baseline Infrastructure + Vulnerable Cloud Analytics Expansion
# Intentionally introduces critical security regression for hackathon demo:
# 1. Public SSH Ingress on port 22 (0.0.0.0/0) — MITRE T1190
# 2. Wildcard IAM Access Policy (Action: *, Resource: *) — MITRE T1078.004
# 3. Publicly accessible unencrypted S3 bucket with sensitive customer data — MITRE T1530
# 
# Attack Engine will detect reachable exploit chain:
# Internet -> Public Ingress -> Analytics EC2 -> Wildcard IAM -> S3 Customer Data / RDS DB

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

resource "aws_security_group" "private_app_sg" {
  name        = "private-app-security-group"
  description = "Restricted ingress for internal application tier"
  vpc_id      = aws_vpc.production_vpc.id

  ingress {
    description = "SSH from internal bastion only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
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
    Sensitivity = "high"
  }
}

# --- INSECURE PULL REQUEST CHANGES (VULNERABILITY REGRESSION) ---

resource "aws_security_group" "public_analytics_sg" {
  name        = "public-analytics-security-group"
  description = "VULNERABILITY: Unrestricted public SSH and web access"
  vpc_id      = aws_vpc.production_vpc.id

  ingress {
    description = "Open SSH from entire Internet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Open HTTP"
    from_port   = 80
    to_port     = 80
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
    Risk        = "Critical"
  }
}

resource "aws_iam_role" "analytics_admin_role" {
  name = "analytics-admin-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "analytics_wildcard_policy" {
  name = "analytics-wildcard-policy"
  role = aws_iam_role.analytics_admin_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = "*"
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "analytics_instance_profile" {
  name = "analytics-instance-profile"
  role = aws_iam_role.analytics_admin_role.name
}

resource "aws_instance" "analytics_server" {
  ami                  = "ami-0c55b159cbfafe1f0"
  instance_type        = "t3.micro"
  vpc_security_group_ids = [aws_security_group.public_analytics_sg.id]
  iam_instance_profile = aws_iam_instance_profile.analytics_instance_profile.name

  tags = {
    Name        = "public-analytics-server"
    Environment = "production"
  }
}

resource "aws_s3_bucket" "customer_financial_records" {
  bucket = "prod-customer-financial-records"
  acl    = "public-read"

  tags = {
    Name               = "customer-financial-records"
    Environment        = "production"
    DataClassification = "confidential"
    Sensitivity        = "high"
  }
}
