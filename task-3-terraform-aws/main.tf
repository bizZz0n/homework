terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Local state for demo; production uses S3 backend
  # backend "s3" {
  #   bucket         = "my-terraform-state"
  #   key            = "vpc/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

# AWS Provider configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      CreatedAt   = timestamp()
    }
  }
}

# VPC Module: Creates VPC, subnets, NAT gateways, route tables
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  # Availability zones (for multi-AZ redundancy)
  azs = var.availability_zones

  # Public subnets: route to Internet Gateway
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  # DNS settings
  enable_dns_hostnames = true
  enable_dns_support   = true

  # NAT Gateway configuration
  enable_nat_gateway = true
  single_nat_gateway = false  # One NAT per AZ for HA (not cost-optimized)

  # VPN Gateway (not needed for this demo)
  enable_vpn_gateway = false

  # VPC Flow Logs (captures network traffic for debugging/security)
  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true
  flow_log_cloudwatch_log_group_retention_in_days = 7

  # Kubernetes specific tags (if using EKS)
  # Uncomment if planning to use with EKS
  # public_subnet_tags = {
  #   "kubernetes.io/role/elb"                    = "1"
  #   "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  # }
  # private_subnet_tags = {
  #   "kubernetes.io/role/internal-elb"           = "1"
  #   "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  # }

  tags = {
    Tier = "Networking"
  }
}

# Example: Subnet outputs can be used by downstream resources (e.g., RDS, ECS)
# This demonstrates how Terraform chains resources together
output "subnet_outputs_for_downstream" {
  description = "Example of how downstream resources consume VPC outputs"
  value = {
    public_subnet_ids  = module.vpc.public_subnets
    private_subnet_ids = module.vpc.private_subnets
    vpc_id             = module.vpc.vpc_id
    nat_gateway_ips    = module.vpc.nat_public_ips
  }
}
