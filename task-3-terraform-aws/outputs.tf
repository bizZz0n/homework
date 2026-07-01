output "environment" {
  value       = terraform.workspace
  description = "Active environment (Terraform workspace)"
}

output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID (for downstream resources like RDS, ECS)"
}

output "vpc_cidr" {
  value       = module.vpc.vpc_cidr_block
  description = "VPC CIDR block"
}

output "public_subnets" {
  value       = module.vpc.public_subnets
  description = "Public subnet IDs (for load balancers, NAT gateways)"
}

output "private_subnets" {
  value       = module.vpc.private_subnets
  description = "Private subnet IDs (for RDS, ElastiCache, ECS tasks)"
}

output "nat_gateway_ips" {
  value       = module.vpc.nat_public_ips
  description = "NAT Gateway public IPs (for whitelisting outbound traffic)"
}

output "nat_gateway_ids" {
  value       = module.vpc.natgw_ids
  description = "NAT Gateway IDs (for monitoring/debugging)"
}

output "internet_gateway_id" {
  value       = module.vpc.igw_id
  description = "Internet Gateway ID"
}

output "availability_zones" {
  value       = module.vpc.azs
  description = "Availability zones in use"
}

# Convenience output for Task 4: Terragrunt can consume these
output "vpc_summary" {
  value = {
    vpc_id             = module.vpc.vpc_id
    vpc_cidr           = module.vpc.vpc_cidr_block
    public_subnets     = module.vpc.public_subnets
    private_subnets    = module.vpc.private_subnets
    nat_gateway_ips    = module.vpc.nat_public_ips
    availability_zones = module.vpc.azs
  }
  description = "VPC summary for downstream consumers (e.g., Terragrunt)"
}
