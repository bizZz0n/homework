output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID"
}

output "vpc_cidr" {
  value       = module.vpc.vpc_cidr_block
  description = "VPC CIDR block"
}

output "public_subnets" {
  value       = module.vpc.public_subnets
  description = "Public subnet IDs"
}

output "private_subnets" {
  value       = module.vpc.private_subnets
  description = "Private subnet IDs"
}

output "nat_gateway_ips" {
  value       = module.vpc.nat_public_ips
  description = "NAT Gateway public IPs"
}

output "nat_gateway_ids" {
  value       = module.vpc.natgw_ids
  description = "NAT Gateway IDs"
}

output "internet_gateway_id" {
  value       = module.vpc.igw_id
  description = "Internet Gateway ID"
}

# Commonly needed output for EC2/RDS resources
output "subnet_summary" {
  value = {
    vpc_id          = module.vpc.vpc_id
    public_subnets  = module.vpc.public_subnets
    private_subnets = module.vpc.private_subnets
  }
  description = "Summary for downstream resources"
}
