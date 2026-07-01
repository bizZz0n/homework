# Bootstrap: creates the S3 bucket that backs the remote state for the parent
# VPC stack. Locking uses S3's native lockfile (Terraform 1.11+), so no
# DynamoDB table is needed. This solves the chicken-and-egg problem — the
# backend can't exist in the state it is supposed to store, so bootstrap runs
# with LOCAL state (no backend block here).
#
# Run once per account:
#   cd bootstrap
#   terraform init
#   terraform apply
#
# Then wire the parent stack:
#   cd ..
#   terraform init -backend-config=backend.hcl

terraform {
  required_version = ">= 1.11"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region for the state bucket and lock table"
}

variable "state_bucket_name" {
  type        = string
  description = "Globally-unique name for the S3 state bucket (match backend.hcl)"
}

# S3 bucket that stores Terraform state
resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket_name

  tags = {
    Purpose   = "terraform-remote-state"
    ManagedBy = "Terraform"
  }
}

# Keep a version history of every state file (recover from bad applies)
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# State can contain secrets — block all public access
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "state_bucket" {
  value       = aws_s3_bucket.state.id
  description = "Name of the S3 state bucket (use in backend.hcl)"
}
