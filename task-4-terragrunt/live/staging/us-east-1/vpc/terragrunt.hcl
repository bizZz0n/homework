# VPC Component for Staging
# Similar to dev, but with HA and more robust configuration

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/vpc"
}

inputs = {
  vpc_name           = "staging-vpc-us-east-1"
  vpc_cidr           = "10.1.0.0/16"  # Different CIDR
  azs                = ["us-east-1a", "us-east-1b"]
  public_subnets    = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnets   = ["10.1.101.0/24", "10.1.102.0/24"]
  aws_region        = "us-east-1"
  enable_nat_gateway = true  # Required for staging
  enable_flow_log    = true
}

# Interview question: "How is staging different from dev?"
# Answer: VPC CIDR is different (10.1.0.0 vs 10.0.0.0), multi-AZ for HA
