variable "vpc_name" {
  type        = string
  description = "Name of the VPC"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for VPC"
}

variable "azs" {
  type        = list(string)
  description = "Availability zones"
}

variable "public_subnets" {
  type        = list(string)
  description = "Public subnet CIDR blocks"
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnet CIDR blocks"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "environment" {
  type        = string
  description = "Environment (dev, staging, prod)"
}

variable "enable_nat_gateway" {
  type        = bool
  default     = true
  description = "Enable NAT Gateway"
}

variable "enable_flow_log" {
  type        = bool
  default     = true
  description = "Enable VPC Flow Logs"
}

variable "multi_az" {
  type        = bool
  default     = true
  description = "Enable multi-AZ deployment"
}

variable "log_retention_days" {
  type        = number
  default     = 7
  description = "CloudWatch log retention days"
}
