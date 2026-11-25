terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
}

resource "aws_s3_bucket" "data" {
  bucket = "my-company-data-bucket"
}

resource "aws_s3_bucket_public_access_block" "data_pab" {
  bucket = aws_s3_bucket.data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_enc" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "data_ver" {
  bucket = aws_s3_bucket.data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Security group for web server with restricted access"

  ingress {
    description = "Allow SSH from internal network only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "Allow MySQL from internal network only"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
}

resource "aws_iam_policy" "admin" {
  name        = "s3-read-only-policy"
  description = "Least privilege policy for reading S3 data bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        "arn:aws:s3:::my-company-data-bucket",
        "arn:aws:s3:::my-company-data-bucket/*"
      ]
    }]
  })
}

resource "aws_db_instance" "main" {
  identifier                     = "mydb"
  engine                         = "mysql"
  engine_version                 = "8.0"
  instance_class                 = "db.t3.micro"
  allocated_storage              = 20
  username                       = "admin"
  password                       = "Password123!"
  publicly_accessible            = false
  storage_encrypted              = true
  auto_minor_version_upgrade     = true
  iam_database_authentication_enabled = true
  deletion_protection            = true
  multi_az                       = true
  copy_tags_to_snapshot          = true
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  skip_final_snapshot            = true
}

resource "aws_instance" "web" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t3.micro"
  ebs_optimized = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }
}

resource "aws_s3_bucket" "public_bucket" {
  bucket = "my-public-test-bucket"
}

resource "aws_s3_bucket_acl" "public" {
  bucket = aws_s3_bucket.public_bucket.id
  acl    = "public-read"
}