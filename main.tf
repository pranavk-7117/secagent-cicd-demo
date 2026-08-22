# Secure Baseline Infrastructure (main branch)
# - VPC scoped to private CIDR 10.0.0.0/16
# - SSH ingress restricted to internal CIDR only (no 0.0.0.0/0)
# - Encrypted RDS PostgreSQL Database with public access disabled

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

resource "aws_instance" "app_server" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
  vpc_security_group_ids = [aws_security_group.private_app_sg.id]

  tags = {
    Name        = "production-app-server"
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
# Insecure Pull Request Change (feature/insecure-change branch)
# Introduces:
# 1. Open SSH ingress to 0.0.0.0/0 on security group (T1190 Exploit Public-Facing App)
# 2. Wildcard IAM Role with Action: "*" and Resource: "*" (T1078.004 Cloud Account Takeover)
# 3. Instance profile connecting public compute to wildcard IAM
# 4. Public access to production database (T1530 Data Exfiltration)
#
# Result: Creates deterministic attack path:
# Internet -> Public SG -> EC2 -> IAM Wildcard -> Production RDS Database

resource "aws_security_group" "public_web_sg" {
  name        = "public-web-security-group"
  description = "Dangerous open SSH ingress"
  vpc_id      = aws_vpc.production_vpc.id

  ingress {
    description = "SSH from anywhere - VULNERABILITY"
    from_port   = 22
    to_port     = 22
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
      Action   = "*"
      Effect   = "Allow"
      Resource = "*"
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
    Name        = "exposed-web-server"
    Environment = "production"
  }
}
