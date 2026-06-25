# Task 4: Terragrunt Multi-Environment — DRY Infrastructure as Code

## Objective

Demonstrate **DRY (Don't Repeat Yourself) infrastructure management** across multiple environments and regions using Terragrunt folder hierarchy and terragrunt.hcl configuration.

**Demonstration goal**: Show how to eliminate Terraform duplication when managing 100s of environment/region/component combinations. Live demo: promote dev → staging.

---

## The Problem Terragrunt Solves

### Without Terragrunt (Anti-Pattern)

```
terraform-prod/
├── main.tf (copy of Task 3)
├── variables.tf (copy)
├── terraform.tfvars (prod values)

terraform-staging/
├── main.tf (DUPLICATE copy)
├── variables.tf (DUPLICATE copy)
├── terraform.tfvars (staging values)

terraform-dev/
├── main.tf (DUPLICATE copy again!)
├── variables.tf (DUPLICATE copy again!)
├── terraform.tfvars (dev values)
```

**Problems**:
- 📋 3× copy-paste of main.tf, variables.tf
- 🐛 Bug fixes need to land in 3 places
- 💥 Merge conflicts across environments
- 📈 Scales to nightmare at 50+ environments

### With Terragrunt (Chosen)

```
live/
├── terragrunt.hcl (root config, included by all)
├── dev/
│   ├── terragrunt.hcl (dev values)
│   ├── us-east-1/
│   │   ├── vpc/
│   │   │   └── terragrunt.hcl (points to modules/vpc)
│   │   └── ec2/
│   │       └── terragrunt.hcl
│   └── eu-west-1/
│       ├── vpc/
│       └── ec2/
├── staging/
│   ├── terragrunt.hcl (staging values)
│   ├── us-east-1/
│   │   ├── vpc/
│   │   └── ec2/
│   └── eu-west-1/
└── prod/
    ├── terragrunt.hcl (prod values)
    ├── us-east-1/
    └── eu-west-1/

modules/
├── vpc/
│   ├── main.tf (SINGLE copy)
│   ├── variables.tf (SINGLE copy)
│   └── outputs.tf
├── ec2/
│   └── ...
└── rds/
    └── ...
```

**Benefits**:
- ✅ Single Terraform source (modules/)
- ✅ Environment-specific overrides via terragrunt.hcl
- ✅ Folder hierarchy visualizes env/region/component structure
- ✅ Promotion: `cp -r live/dev/us-east-1/vpc live/staging/us-east-1/vpc` + update tfvars
- ✅ Scales to 1000s of components

---

## Terragrunt Concepts

### 1. Remote State Configuration

```hcl
# live/terragrunt.hcl
remote_state {
  backend = "s3"
  config = {
    bucket         = "my-terraform-state"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
  generate_backend = true  # Auto-generates backend block
}
```

**Why**:
- ✅ Remote state enables team collaboration
- ✅ DynamoDB locks prevent concurrent applies
- ✅ Encryption protects sensitive data
- ✅ Single bucket + dynamic key paths = organized state

### 2. Inputs (Variable Override)

```hcl
# live/terragrunt.hcl
inputs = {
  environment = get_env("TF_ENV", "dev")
  region      = get_env("TF_REGION", "us-east-1")
}

# live/dev/terragrunt.hcl (included by all dev components)
inputs = merge(
  read_terragrunt_config(find_in_parent_folders()).inputs,
  {
    environment = "dev"
    project     = "platform-eng"
  }
)
```

**Result**: All Terraform variables inherit from parent, component overrides.

### 3. Locals (Helper Variables)

```hcl
locals {
  env  = "dev"
  path = path_relative_to_include()  # "vpc", "ec2", etc.
}
```

**Use case**: Build dynamic state key, component path, etc.

### 4. Dependency Management

```hcl
# live/dev/us-east-1/ec2/terragrunt.hcl
dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    vpc_id = "vpc-mock-12345"
  }
}

inputs = {
  vpc_id = dependency.vpc.outputs.vpc_id  # Use VPC output as EC2 input
}
```

**Result**: EC2 automatically fetches VPC ID. No manual variable passing.

### 5. Generate Blocks (DRY Provider Config)

```hcl
# live/terragrunt.hcl
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
      region = "${var.aws_region}"
    }
  EOF
}
```

**Result**: No need to copy provider block to every component. Terragrunt generates it.

---

## Folder Structure

```
task-4-terragrunt/
├── README.md (this file)
├── terragrunt.hcl (root: remote state, provider, common inputs)
├── live/
│   ├── dev/
│   │   ├── terragrunt.hcl (dev defaults)
│   │   ├── us-east-1/
│   │   │   ├── vpc/
│   │   │   │   ├── terragrunt.hcl (points to ../../modules/vpc)
│   │   │   │   └── terraform.tfvars (vpc-specific dev values)
│   │   │   └── ec2/
│   │   │       ├── terragrunt.hcl
│   │   │       └── terraform.tfvars
│   │   └── eu-west-1/
│   │       ├── vpc/
│   │       └── ec2/
│   ├── staging/
│   │   ├── terragrunt.hcl (staging defaults)
│   │   ├── us-east-1/
│   │   │   ├── vpc/
│   │   │   └── ec2/
│   │   └── eu-west-1/
│   └── prod/
│       ├── terragrunt.hcl (prod defaults: larger instances, HA)
│       ├── us-east-1/
│       └── eu-west-1/
└── modules/
    ├── vpc/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── ec2/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── rds/
        └── ...
```

---

## Setup & Execution

### Prerequisites

```bash
brew install terragrunt

# Verify installation
terragrunt --version
```

### Plan All Components (Dev)

```bash
cd task-4-terragrunt

# Generate Terraform files from terragrunt config
terragrunt run-all init --terragrunt-working-dir live/dev

# Plan all dev components (vpc, ec2, etc.)
terragrunt run-all plan --terragrunt-working-dir live/dev

# Output: Execution plan for each component
# Expected output shows VPC + EC2 resources for both regions
```

### Plan Single Component

```bash
# Plan only dev/us-east-1/vpc
cd live/dev/us-east-1/vpc
terragrunt plan
```

### Promotion Demo: dev → staging

```bash
# Scenario: Promote dev configuration to staging

# 1. Copy dev to staging
cp -r live/dev/us-east-1/vpc live/staging/us-east-1/vpc

# 2. Update staging values
vi live/staging/us-east-1/vpc/terraform.tfvars
# Change: instance_count = 2  (HA for staging)
# Change: instance_type = t3.small → t3.medium

# 3. Plan staging
cd live/staging/us-east-1/vpc
terragrunt plan

# 4. Review diff (what changes from dev to staging)
# Apply if approved
terragrunt apply

# Result: Staging VPC now deployed with higher capacity
```

---

## File Examples

### Root terragrunt.hcl

```hcl
# Included by all components (env/region/component)
# Sets up remote state, provider, common inputs

remote_state {
  backend = "s3"
  config = {
    bucket         = "my-terraform-state"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
  }
  generate_backend = true
}

# Auto-generate AWS provider
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
    }
  EOF
}

# Common inputs (inherited by all)
inputs = {
  project_name = "platform-engineering"
  managed_by   = "Terragrunt"
}
```

### live/dev/terragrunt.hcl

```hcl
# Environment defaults (overridden by component if needed)
# Included by dev/region/component via find_in_parent_folders()

locals {
  root_inputs = read_terragrunt_config(find_in_parent_folders()).inputs
}

inputs = merge(
  local.root_inputs,
  {
    environment         = "dev"
    aws_region          = get_env("AWS_REGION", "us-east-1")
    enable_detailed_monitoring = false  # Cost optimization for dev
  }
)
```

### live/dev/us-east-1/vpc/terragrunt.hcl

```hcl
# VPC component configuration
# Points to modules/vpc source

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../modules/vpc"
}

# VPC-specific inputs
inputs = {
  vpc_name = "dev-vpc-us-east-1"
  vpc_cidr = "10.0.0.0/16"
  azs      = ["us-east-1a", "us-east-1b"]
}
```

### live/dev/us-east-1/ec2/terragrunt.hcl

```hcl
# EC2 component configuration
# Depends on VPC (via dependency block)

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../modules/ec2"
}

# Fetch VPC ID from upstream component
dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  instance_count = 1
  instance_type  = "t3.micro"  # Dev is minimal
  vpc_id         = dependency.vpc.outputs.vpc_id  # Automatic
  subnet_id      = dependency.vpc.outputs.public_subnets[0]
}
```

---

## Promotion Workflow

### Scenario: Promote dev to staging

**Step 1: Copy configuration**
```bash
cp -r live/dev/us-east-1 live/staging/us-east-1
```

**Step 2: Update values for staging**
```hcl
# live/staging/us-east-1/vpc/terragrunt.hcl
inputs = {
  vpc_name = "staging-vpc-us-east-1"  # Changed
  multi_az = true  # Staging needs HA
}

# live/staging/us-east-1/ec2/terragrunt.hcl
inputs = {
  instance_count = 2  # HA
  instance_type  = "t3.small"  # Bigger than dev
}
```

**Step 3: Plan before apply**
```bash
cd live/staging/us-east-1/vpc
terragrunt plan  # Review changes

cd ../ec2
terragrunt plan  # Review changes
```

**Step 4: Apply**
```bash
# Option A: Apply single component
terragrunt apply

# Option B: Apply all staging components
terragrunt run-all apply --terragrunt-working-dir live/staging
```

**Result**: Staging environment now mirrors dev structure but with different capacity/HA settings.

---

## Key Terraform Concepts in Terragrunt

### 1. Module Reusability

```
modules/vpc/main.tf ← used by
  - live/dev/us-east-1/vpc
  - live/dev/eu-west-1/vpc
  - live/staging/us-east-1/vpc
  - live/prod/us-east-1/vpc
  - (all reference same source)
```

**Result**: Bug fix to module lands everywhere. No copy-paste.

### 2. Folder Structure = Environment/Region/Component

```
live/
├── dev/          (environment)
│   ├── us-east-1/  (region)
│   │   ├── vpc/    (component)
│   │   └── ec2/    (component)
│   └── eu-west-1/  (region)
```

**Benefits**:
- ✅ Visual organization
- ✅ Mirrors real infrastructure topology
- ✅ Easy to add new region (cp -r us-east-1 eu-west-1)

### 3. Dependencies Between Components

```
├── vpc/          ← creates VPC, subnets
│   └── outputs: vpc_id, subnet_ids
└── ec2/          ← depends on vpc
    └── reads VPC outputs as inputs
```

**Without Terragrunt**: Manually pass VPC ID to EC2 tfvars.
**With Terragrunt**: dependency block auto-fetches.

### 4. run-all for Batch Operations

```bash
# Apply all components in dependency order
terragrunt run-all apply --terragrunt-working-dir live/dev

# Terragrunt automatically:
# 1. Detects dependencies
# 2. Applies vpc first (no dependencies)
# 3. Applies ec2 after (depends on vpc)
```

---

## Failure Modes & Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| **State key mismatch** | `path_relative_to_include()` wrong | Verify folder structure matches state key |
| **Dependency not found** | Dependency config_path doesn't exist | Check relative path (../ correct?) |
| **run-all hangs** | Circular dependency or network | Check for A→B→A; verify AWS credentials |
| **generate provider conflicts** | Multiple generate "provider" blocks | Keep root generate only; use include |

---

## What's NOT Included

- **AWS provisioning**: Plan only; no apply (cost). Apply follows code review.
- **CI/CD integration**: Task 5 covers this (GitHub Actions runner).
- **Policy as Code**: Could add Sentinel/OPA; not needed for demo.
- **Observability**: Terraform state locking works; advanced monitoring not included.

---

## Interview Talking Points

1. **"Why Terragrunt over plain Terraform workspaces?"**
   → Folder hierarchy is more scalable. Workspaces don't support regional splits or component isolation.

2. **"How do you prevent someone applying prod without review?"**
   → CI/CD pipeline (Task 5). Require PR review before merge to main. Apply only runs in CI.

3. **"What if you add a new region?"**
   → `cp -r us-east-1 new-region`. Update region variable. That's it.

4. **"How many components can one team manage?"**
   → Hundreds. Terragrunt scales linearly (one terragrunt.hcl per component).

5. **"Demo the dev → staging promotion."**
   → Copy folder, change values, terragrunt plan, terragrunt apply.

---

## Success Criteria

- [ ] All terragrunt.hcl files valid (terragrunt init works)
- [ ] terragrunt run-all plan shows resources for multiple components
- [ ] Dependency resolution works (ec2 finds vpc outputs)
- [ ] You can describe promotion workflow without notes
- [ ] Folder structure matches env/region/component hierarchy

---

## Next Steps

→ [Task 5: CI Composite Action](../task-5-ci-composite-action/README.md)
