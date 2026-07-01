# Partial backend configuration for the S3 remote state.
# Backend blocks cannot reference variables, so these values are supplied at init:
#   terraform init -backend-config=backend.hcl
#
# The bucket must exist first — see bootstrap/ .
# Replace <ACCOUNT_ID> (or any globally-unique suffix) before use.

bucket = "platform-engineering-tfstate-<ACCOUNT_ID>"
key    = "networking/vpc.tfstate"
region = "us-east-1"

# With workspaces, actual state path becomes:
#   env/<workspace>/networking/vpc.tfstate
workspace_key_prefix = "env"

# Native S3 locking (Terraform 1.11+) — writes a <key>.tflock object.
# No DynamoDB table required.
use_lockfile = true
encrypt      = true
