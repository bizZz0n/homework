terraform {
  # 1.11+ required for native S3 state locking (use_lockfile, no DynamoDB).
  required_version = ">= 1.11"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state in S3 with native S3 lockfile (no DynamoDB).
  # Values are supplied via partial config (backend blocks can't use variables):
  #   terraform init -backend-config=backend.hcl
  # With workspaces, state is stored per-workspace at:
  #   s3://<bucket>/<workspace_key_prefix>/<workspace>/<key>
  backend "s3" {}
}

# AWS Provider configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = terraform.workspace
      ManagedBy   = "Terraform"
    }
  }
}

locals {
  # Environment is the active Terraform workspace (dev / staging / prod).
  env = terraform.workspace

  # Per-environment networking. Each workspace gets its own CIDR range so
  # VPCs can peer without overlap. dev/staging use a single NAT gateway to
  # save cost; prod runs one NAT per AZ for high availability.
vpc_cidr           = "10.0.0.0/14"
  env_config = {
    dev = {
      vpc_cidr           = cidrsubnet(local.vpc_cidr, 2, 0) #
      availability_zones = ["us-east-1a", "us-east-1b"]
      public_subnets     = cidrsubnets(local.vpc_cidr, 10, 10, 1)
      private_subnets    = ["10.0.101.0/24", "10.0.102.0/24"]
      single_nat_gateway = true
    }
    staging = {
      vpc_cidr           = cidrsubnet(local.vpc_cidr, 2, 1) #
      availability_zones = ["us-east-1a", "us-east-1b"]
      public_subnets     = ["10.1.1.0/24", "10.1.2.0/24"]
      private_subnets    = ["10.1.101.0/24", "10.1.102.0/24"]
      single_nat_gateway = true
    }
    prod = {
      vpc_cidr           = cidrsubnet(local.vpc_cidr, 2, 2) #
      availability_zones = ["us-east-1a", "us-east-1b"]
      public_subnets     = ["10.2.1.0/24", "10.2.2.0/24"]
      private_subnets    = ["10.2.101.0/24", "10.2.102.0/24"]
      single_nat_gateway = false
    }
  }

  # lookup() with a fallback keeps `terraform validate` (which runs in the
  # "default" workspace) from erroring on a missing key. Real plan/apply in an
  # unknown workspace is still blocked by the workspace_guard precondition below.
  cfg = lookup(local.env_config, local.env, local.env_config["dev"])
}

# Fail early with a clear message if run in an unknown workspace
# (e.g. the "default" workspace) instead of a cryptic index error.
resource "terraform_data" "workspace_guard" {
  lifecycle {
    precondition {
      condition     = contains(keys(local.env_config), local.env)
      error_message = "Workspace must be one of ${join(", ", keys(local.env_config))}. Got: ${local.env}. Run: terraform workspace select <env>"
    }
  }
}

# VPC Module: Creates VPC, subnets, NAT gateways, route tables
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.vpc_name}-${local.env}"
  cidr = local.cfg.vpc_cidr

  # Availability zones (for multi-AZ redundancy)
  azs = local.cfg.availability_zones

  # Public subnets: route to Internet Gateway
  public_subnets  = local.cfg.public_subnets
  private_subnets = local.cfg.private_subnets

  # DNS settings
  enable_dns_hostnames = true
  enable_dns_support   = true

  # NAT Gateway configuration (per-env: single in dev/staging, HA in prod)
  enable_nat_gateway = true
  single_nat_gateway = local.cfg.single_nat_gateway

  # VPN Gateway (not needed for this demo)
  enable_vpn_gateway = false

  # VPC Flow Logs (captures network traffic for debugging/security)
  enable_flow_log                                 = true
  create_flow_log_cloudwatch_iam_role             = true
  create_flow_log_cloudwatch_log_group            = true
  flow_log_cloudwatch_log_group_retention_in_days = 7

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
