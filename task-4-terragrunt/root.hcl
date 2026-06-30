# Root terragrunt.hcl
# Included by all live/env/region/component directories
# Configures remote state, provider, and common inputs

# Remote state: this demo uses Terraform's default LOCAL state, so no
# remote_state block is configured.
#
# For production (team collaboration, state locking), add an S3 backend, e.g.:
# remote_state {
#   backend = "s3"
#   generate = {
#     path      = "backend.tf"
#     if_exists = "overwrite"
#   }
#   config = {
#     bucket         = "my-terraform-state-${get_aws_account_id()}"
#     key            = "${path_relative_to_include()}/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "terraform-locks"
#     encrypt        = true
#   }
# }

# Auto-generate AWS provider configuration
# Prevents copy-paste of the provider block. required_providers is NOT
# generated here — each module declares its own, and Terraform allows only
# one required_providers configuration per module.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<-EOF
    provider "aws" {
      region = var.aws_region

      default_tags {
        tags = {
          ManagedBy   = "Terragrunt"
          Project     = "platform-engineering"
        }
      }
    }
  EOF
}

# Common inputs inherited by all components
inputs = {
  project_name = "platform-engineering"
  managed_by   = "Terragrunt"
}

# Local variables (computed, not overridable)
locals {
  # Current environment (extracted from folder structure)
  env = element(split("/", path_relative_to_include()), 0)

  # Current region (extracted from folder structure)
  region = element(split("/", path_relative_to_include()), 1)

  # Current component (extracted from folder structure)
  component = element(split("/", path_relative_to_include()), 2)
}

# Configuration for before/after hooks (optional)
# Useful for pre-checks, validation, cleanup
# Hook examples (uncomment to enable):

# terraform_init_options = ["--upgrade"]

# before_hook "validate" {
#   commands = ["plan", "apply"]
#   execute  = ["sh", "-c", "echo 'Validating configuration...'"]
#   run_on_error = false
# }

# after_hook "run_tests" {
#   commands = ["apply"]
#   execute  = ["sh", "-c", "echo 'Infrastructure deployed!'"]
#   run_on_error = false
# }
