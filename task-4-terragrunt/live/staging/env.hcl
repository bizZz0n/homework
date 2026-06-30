# Staging environment defaults
# Closer to production: HA, backups enabled, monitoring

include "root" {
  path = find_in_parent_folders()
}

inputs = {
  environment               = "staging"
  instance_type             = "t3.small"  # Balance cost/performance
  enable_detailed_monitoring = true  # Enable monitoring
  multi_az                  = true  # HA for staging
  backup_retention_days     = 7  # Weekly backups
  log_retention_days        = 30  # Monthly retention
}

locals {
  env = "staging"
}
