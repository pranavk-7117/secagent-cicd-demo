resource "aws_security_group" "public_sg" {
  name        = "public-analytics-security-group"
  description = "Open SSH access from anywhere"

  ingress {
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
}

resource "aws_iam_role" "app_role" {
  name = "analytics-admin-role"
}

resource "aws_iam_role_policy" "app_policy" {
  name = "analytics-wildcard-policy"
  role = aws_iam_role.app_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "*",
      "Resource": "*",
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
  tags = {
    Environment = "production"
    Sensitivity = "high"
  }
}
