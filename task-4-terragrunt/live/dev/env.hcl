# Development environment defaults
# Included by all dev/region/component units (as the "env" include).
# This file holds inputs/locals only; units include root.hcl separately.

# Environment-specific inputs (inherited by all dev components)
inputs = {
  environment               = "dev"
  instance_type             = "t3.micro"  # Minimal cost
  enable_detailed_monitoring = false  # Cost optimization
  multi_az                  = false  # Single AZ for dev
  backup_retention_days     = 1  # Minimal backups
  log_retention_days        = 3  # Short retention
}

# Dev environment metadata
locals {
  env = "dev"
}
