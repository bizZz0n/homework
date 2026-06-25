# Terraform variables for VPC provisioning
# These are default values; override via CLI or -var-file

aws_region         = "us-east-1"
project_name       = "platform-engineering"
environment        = "dev"
vpc_name           = "main-vpc"

# CIDR block for VPC (provides 65536 IP addresses)
vpc_cidr           = "10.0.0.0/16"

# Multi-AZ for redundancy
availability_zones = ["us-east-1a", "us-east-1b"]

# Public subnets (route to Internet Gateway)
# Each /24 provides 256 IP addresses
public_subnets    = ["10.0.1.0/24", "10.0.2.0/24"]

# Private subnets (route to NAT Gateway)
# For production, consider larger private subnets
private_subnets   = ["10.0.101.0/24", "10.0.102.0/24"]

# To use for different environments, override like:
# terraform apply -var-file=dev.tfvars
# terraform apply -var-file=staging.tfvars
# terraform apply -var-file=prod.tfvars
#
# OR use Terragrunt (Task 4) for cleaner multi-env management
