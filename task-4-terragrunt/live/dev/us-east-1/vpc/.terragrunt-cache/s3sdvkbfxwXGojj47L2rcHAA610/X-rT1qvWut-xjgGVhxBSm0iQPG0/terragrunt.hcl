# VPC Component Configuration
# Points to modules/vpc Terraform source

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path           = find_in_parent_folders("env.hcl")
  merge_strategy = "deep"
}

# Terraform configuration
terraform {
  source = "../../../../modules/vpc"
}

# VPC-specific inputs
inputs = {
  vpc_name           = "dev-vpc-us-east-1"
  vpc_cidr           = "10.0.0.0/16"
  azs                = ["us-east-1a", "us-east-1b"]
  public_subnets    = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets   = ["10.0.101.0/24", "10.0.102.0/24"]
  aws_region        = "us-east-1"
  enable_nat_gateway = true
  enable_flow_log    = true
}
