# Development environment defaults
# Included by all dev/region/component directories

# Include root configuration
include "root" {
  path = find_in_parent_folders()
}

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
