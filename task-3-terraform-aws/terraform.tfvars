# Cross-environment defaults for VPC provisioning.
# Per-environment networking (CIDR, subnets, AZs, NAT strategy) is NOT here —
# it is selected by the active Terraform workspace via env_config in main.tf.
#
#   terraform workspace select dev|staging|prod
#   terraform plan
#
# Only values shared across all environments live here.

aws_region   = "us-east-1"
project_name = "platform-engineering"
vpc_name     = "main-vpc"
