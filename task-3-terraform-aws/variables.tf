variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region for VPC deployment"
}

variable "project_name" {
  type        = string
  default     = "platform-engineering"
  description = "Project name for resource tagging"
}

variable "vpc_name" {
  type        = string
  default     = "main-vpc"
  description = "Base name of the VPC (workspace name is appended, e.g. main-vpc-dev)"
}

# NOTE: Environment and per-environment networking (CIDR, subnets, AZs, NAT
# strategy) are no longer variables. They are selected by the active Terraform
# workspace via the env_config map in main.tf. Switch env with:
#   terraform workspace select dev|staging|prod
