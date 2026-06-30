# Production environment defaults
# Highest reliability: HA across regions, encrypted backups, comprehensive monitoring
# Holds inputs/locals only; units include root.hcl separately.

inputs = {
  environment               = "prod"
  instance_type             = "t3.medium"  # Performance-focused
  enable_detailed_monitoring = true  # Full observability
  multi_az                  = true  # Multi-AZ required
  backup_retention_days     = 30  # Monthly backups
  log_retention_days        = 365  # Annual retention (compliance)
  enable_encryption         = true  # Encryption required
  enable_cross_region_backup = true  # Disaster recovery
}

locals {
  env = "prod"
}
