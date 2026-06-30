# VPC Module: Shared infrastructure for all environments/regions
# Used by both dev and staging (and prod, if added)

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Use terraform-aws-modules/vpc like in Task 3
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs            = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = !var.multi_az  # One NAT if single AZ, one per AZ if multi-AZ

  enable_vpn_gateway = false

  enable_flow_log                      = var.enable_flow_log
  create_flow_log_cloudwatch_iam_role  = var.enable_flow_log
  create_flow_log_cloudwatch_log_group = var.enable_flow_log
  flow_log_cloudwatch_log_group_retention_in_days = var.log_retention_days

  tags = {
    Component   = "vpc"
    Environment = var.environment
  }
}
