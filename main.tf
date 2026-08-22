# Secure Baseline Infrastructure + Hardened Cloud Expansion
# - VPC scoped to private CIDR 10.0.0.0/16
# - SSH ingress restricted to internal CIDR (10.0.0.0/16)
# - HTTPS (443) ingress allowed for web tier
# - Least-privilege IAM policies scoped to specific ARNs
# - Encrypted RDS PostgreSQL Database with public access disabled
# - Private encrypted S3 bucket with Public Access Block enabled

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

resource "aws_security_group" "hardened_web_sg" {
  name        = "hardened-web-security-group"
  description = "Hardened security group with restricted SSH and HTTPS only"
  vpc_id      = aws_vpc.production_vpc.id

  ingress {
    description = "HTTPS public web traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from internal VPC only (Remediated)"
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
    Security    = "Hardened"
  }
}

resource "aws_iam_role" "scoped_app_role" {
  name = "production-scoped-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "scoped_app_policy" {
  name = "scoped-app-policy"
  role = aws_iam_role.scoped_app_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["s3:GetObject", "s3:PutObject"]
      Effect   = "Allow"
      Resource = "arn:aws:s3:::production-secure-data-store/*"
    }]
  })
}

resource "aws_iam_instance_profile" "scoped_app_profile" {
  name = "scoped-app-profile"
  role = aws_iam_role.scoped_app_role.name
}

resource "aws_instance" "production_web_server" {
  ami                  = "ami-0c55b159cbfafe1f0"
  instance_type        = "t3.micro"
  vpc_security_group_ids = [aws_security_group.hardened_web_sg.id]
  iam_instance_profile = aws_iam_instance_profile.scoped_app_profile.name

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
    Sensitivity = "high"
  }
}

resource "aws_s3_bucket" "production_data_store" {
  bucket = "production-secure-data-store"
  acl    = "private"

  tags = {
    Name        = "production-data-store"
    Environment = "production"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_encryption" {
  bucket = aws_s3_bucket.production_data_store.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "s3_public_block" {
  bucket = aws_s3_bucket.production_data_store.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
