# Secure Baseline Infrastructure + Hardened Cloud Analytics Expansion (Remediated)
# Applied SecAgent Closed-Loop Fix:
# 1. Scoped SSH port 22 to internal VPC CIDR (10.0.0.0/16)
# 2. Scoped IAM role policy from wildcard (*) to least-privilege specific resource ARNs
# 3. Encrypted RDS PostgreSQL Database with public access disabled

resource "aws_security_group" "public_sg" {
  name        = "public-analytics-security-group"
  description = "Hardened security group with restricted SSH"

  ingress {
    description = "SSH from internal VPC only (SecAgent Remediated)"
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
}

resource "aws_iam_role" "app_role" {
  name = "analytics-admin-role"
}

resource "aws_iam_role_policy" "app_policy" {
  name = "analytics-scoped-policy"
  role = aws_iam_role.app_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::analytics-secure-data/*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "app_profile" {
  name = "analytics-app-profile"
  role = aws_iam_role.app_role.name
}

resource "aws_instance" "app_server" {
  ami                  = "ami-0c55b159cbfafe1f0"
  instance_type        = "t3.micro"
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  iam_instance_profile = aws_iam_instance_profile.app_profile.name

  tags = {
    Name        = "public-analytics-server"
    Environment = "production"
  }
}

resource "aws_db_instance" "prod_db" {
  allocated_storage   = 20
  engine              = "postgres"
  instance_class      = "db.t3.micro"
  password            = "VeryStrongPassword2026!"
  username            = "admin"
  storage_encrypted   = true
  publicly_accessible = false
  tags = {
    Environment = "production"
  }
}
