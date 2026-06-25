# Root terragrunt.hcl
# Included by all live/env/region/component directories
# Configures remote state, provider, and common inputs

# Configure remote state (for team collaboration, state locking)
remote_state {
  backend = "s3"
  config = {
    # For demo: local state is fine
    # For production: uncomment and configure S3 bucket
    # bucket         = "my-terraform-state-${get_aws_account_id()}"
    # key            = "${path_relative_to_include()}/terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "terraform-locks"
    # encrypt        = true

    # Demo uses local state (for this exercise)
    skip = true
  }

  # Uncomment to auto-generate backend block from config above
  # generate_backend = true
}

# Auto-generate AWS provider configuration
# Prevents copy-paste of provider block
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<-EOF
    terraform {
      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 5.0"
        }
      }
    }
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
