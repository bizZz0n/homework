# Task 3: Terraform AWS Networking — IaC Foundation

## Objective

Provision AWS VPC + subnets + routing using Terraform and the public `terraform-aws-modules/vpc` module.

**Demonstration goal**: Show pragmatic Terraform use. Use battle-tested modules; show you know when NOT to reinvent.

---

## Architecture & Philosophy

### Why Use Public Modules?

**Anti-pattern: Reinventing VPC**
```hcl
# Don't do this (reinventing the wheel)
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  # ... 50 more lines for tags, flows, etc ...
}

resource "aws_subnet" "public" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, count.index)
  availability_zone = var.availability_zones[count.index]
  # ... more config ...
}

# Repeat for private subnets, NAT gateways, route tables...
# 300+ lines of boilerplate
```

**Pattern: Use public module (chosen)**
```hcl
# Clean, declarative, battle-tested
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "main-vpc"
  cidr = "10.0.0.0/16"
  azs = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false
}
```

**Why modules**:
- ✅ Encapsulation (VPC + subnets + routing bundled)
- ✅ Best practices baked in (NAT gateways, route tables, flow logs)
- ✅ Battle-tested (1000s of orgs use it)
- ✅ Maintainability (module updates apply to all stacks)
- ✅ DRY (no copy-paste across projects)

**Tradeoff**: Less control than raw HCL, but 90% of orgs don't need full control.

---

### Module Selection Criteria

**Why terraform-aws-modules/vpc**?

| Criterion | Module | Why |
|-----------|--------|-----|
| **Popularity** | 3k+ stars, actively maintained | Community validates quality |
| **Completeness** | VPC, subnets, NAT, routes, flow logs | One-stop shop |
| **Flexibility** | Highly parameterized | Scales from simple to complex |
| **Compliance** | Built-in best practices | Security + cost optimization |
| **Support** | Active maintainers, releases | Updates follow AWS changes |

**Could use alternatives?**
- ✅ `awslabs/cloud-foundation-toolkit`: More opinionated, heavier
- ✅ `cloudposse/terraform-aws-vpc`: Similar, slightly different API
- ⚠️ Raw `aws_vpc` resource: Only if you have unusual requirements

**Decision**: Official AWS module (`terraform-aws-modules`) chosen for maximum credibility in interview.

---

## Architecture

```
┌─────────────────────────────────────┐
│         VPC (10.0.0.0/16)           │
├─────────────────────────────────────┤
│                                     │
│  Availability Zone 1 (us-east-1a)   │
│  ┌─────────────────────────────┐    │
│  │ Public Subnet               │    │
│  │ 10.0.1.0/24                 │    │
│  │  - IGW attachment           │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ Private Subnet              │    │
│  │ 10.0.101.0/24               │    │
│  │  - NAT Gateway              │    │
│  └─────────────────────────────┘    │
│                                     │
│  Availability Zone 2 (us-east-1b)   │
│  ┌─────────────────────────────┐    │
│  │ Public Subnet               │    │
│  │ 10.0.2.0/24                 │    │
│  │  - IGW attachment           │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ Private Subnet              │    │
│  │ 10.0.102.0/24               │    │
│  │  - NAT Gateway              │    │
│  └─────────────────────────────┘    │
│                                     │
└─────────────────────────────────────┘
```

**Components**:
- **VPC**: Single VPC, single CIDR block (10.0.0.0/16)
- **Public Subnets**: 2 AZs, route to Internet Gateway
- **Private Subnets**: 2 AZs, route to NAT Gateway
- **NAT Gateways**: 1 per AZ, for outbound internet access
- **Route Tables**: Separate for public/private routing

---

## Files & Structure

```
task-3-terraform-aws/
├── README.md (this file)
├── main.tf (S3 backend + workspace-driven VPC module)
├── variables.tf (cross-env input variables)
├── outputs.tf (export VPC ID, subnet IDs, environment, etc.)
├── terraform.tfvars (cross-env defaults only)
├── backend.hcl (partial S3 backend config for `init -backend-config`)
├── bootstrap/ (one-time: creates the S3 state bucket, local state)
├── terraform.lock.hcl (dependency lock, commit to git)
└── .gitignore (excludes terraform state, secrets)
```

### Environments via Workspaces

Per-environment networking (CIDR, subnets, AZs, NAT strategy) lives in the
`env_config` map in `main.tf`, keyed by `terraform.workspace`. There are no
per-env `.tfvars` files — you switch environments by switching workspace:

| Workspace | VPC CIDR      | NAT gateways      |
|-----------|---------------|-------------------|
| `dev`     | 10.0.0.0/16   | single (cost)     |
| `staging` | 10.1.0.0/16   | single (cost)     |
| `prod`    | 10.2.0.0/16   | one per AZ (HA)   |

State is isolated per workspace in S3 at
`env/<workspace>/networking/vpc.tfstate`. A precondition blocks any run in an
unknown workspace (e.g. `default`).

---

## Setup & Execution

### Prerequisites

```bash
# Install Terraform
brew install terraform

# Configure AWS credentials (not needed for plan, required for apply)
export AWS_REGION=us-east-1
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret
```

### One-Time Bootstrap (creates the state bucket)

The S3 backend can't store its own bucket, so create it once with local state:

```bash
cd task-3-terraform-aws/bootstrap
terraform init
terraform apply -var="state_bucket_name=platform-engineering-tfstate-<ACCOUNT_ID>"
# Put the same bucket name into ../backend.hcl
```

No DynamoDB table — locking uses S3's native lockfile (`use_lockfile = true`,
Terraform 1.11+).

### Init, Select Workspace, Plan

```bash
cd task-3-terraform-aws

# Initialize with the S3 backend (values from backend.hcl)
terraform init -backend-config=backend.hcl

# Create/select the environment (state auto-isolates per workspace)
terraform workspace new dev      # first time
terraform workspace select dev   # thereafter

# Validate syntax (runs in default workspace; that's fine)
terraform validate

# Generate plan for the selected workspace
terraform plan -out=tfplan

# Review plan output
# Expected: ~20 resources (VPC, subnets, NAT gateways, route tables, etc.)
```

> Validating/planning without AWS? Use `terraform init -backend=false` to skip
> the backend and just install providers + modules.

### Understanding the Plan Output

```
# Sample output (first few lines)
Terraform will perform the following actions:

  # module.vpc.aws_eip.nat[0] will be created
  + resource "aws_eip" "nat" {
      + allocation_id = (known after apply)
      + domain        = "vpc"
      + id            = (known after apply)
      # ...
    }

  # module.vpc.aws_internet_gateway.this[0] will be created
  + resource "aws_internet_gateway" "this" {
      + arn      = (known after apply)
      + id       = (known after apply)
      + owner_id = (known after apply)
      # ...
    }

# Key takeaway: Shows all resources that would be created/modified/deleted
# Review before applying (code review best practice)
```

### (OPTIONAL) Apply to Real AWS

**⚠️ Cost implications**: Skip this unless explicitly asked. Plan is sufficient for demo.

```bash
# Apply the plan (actually provisions resources)
terraform apply tfplan

# Verify resources created
aws ec2 describe-vpcs --filters Name=tag:Name,Values=main-vpc

# Clean up when done
terraform destroy
```

---

## Key Terraform Concepts

### 1. Modules

```hcl
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  
  # Inputs
  name = var.vpc_name
  cidr = var.vpc_cidr
  azs = var.availability_zones
  public_subnets = var.public_subnets
  private_subnets = var.private_subnets
}

# Access module outputs
output "vpc_id" {
  value = module.vpc.vpc_id
}
```

**Why**:
- ✅ Encapsulation (module internals hidden)
- ✅ Reusability (use same module across projects)
- ✅ Versioning (pin to stable versions)

### 2. Variables (Flexible Inputs)

```hcl
variable "vpc_name" {
  type = string
  default = "main-vpc"
  description = "VPC name"
}

variable "availability_zones" {
  type = list(string)
  default = ["us-east-1a", "us-east-1b"]
}
```

**Override via CLI or tfvars**:
```bash
terraform apply -var="vpc_name=prod-vpc"
# or from terraform.tfvars file
```

### 3. Outputs (Export Values)

```hcl
output "vpc_id" {
  value = module.vpc.vpc_id
  description = "VPC ID for downstream resources"
}

output "private_subnets" {
  value = module.vpc.private_subnets
  description = "Private subnet IDs (for RDS, etc.)"
}
```

**Use outputs to chain resources** (Task 4 will do this).

### 4. State Management

Terraform maintains `terraform.tfstate` (JSON):
```json
{
  "version": 4,
  "terraform_version": "1.5.0",
  "serial": 3,
  "lineage": "...",
  "outputs": {
    "vpc_id": { "value": "vpc-123abc" }
  },
  "resources": [
    { "type": "aws_vpc", "instances": [...] }
  ]
}
```

**Why it matters**:
- ✅ Source of truth for deployed resources
- ✅ Enables `terraform plan` to diff against reality
- ✅ **Stored remotely** (S3 backend) so a team shares one state

**This project uses remote state**: S3 backend with native S3 locking
(`use_lockfile = true`, Terraform 1.11+) — no DynamoDB table. Workspaces keep
each environment's state in a separate key (`env/<workspace>/...`). Bucket
versioning + SSE are enabled in `bootstrap/` for recovery and encryption.

---

## Failure Modes & Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| **Module not found** | Source path wrong | Check `source` in main.tf; run `terraform init` |
| **Plan shows destroy** | Backend or vars changed | Verify tfvars; run `terraform plan` again |
| **Apply hangs** | AWS rate limiting or timeout | Run with `-lock-timeout=10m` |
| **State corrupted** | Concurrent applies | Don't run apply twice; use remote state with locking |

---

## What's NOT Included

- **Cross-account state**: Single bucket/region; multi-account setups add per-account buckets + assume-role
- **Security groups**: Would add EC2 security rules; out of scope for networking demo
- **VPN/DirectConnect**: Advanced networking; not needed for this demo
- **Multiple regions**: Single region; pattern scales to multi-region (Task 4 will show)

---

## Interview Talking Points

1. **"Why use a module instead of raw resources?"**
   → Encapsulation, best practices, reusability. Don't reinvent VPC.

2. **"How do you scale this to 50 VPCs?"**
   → Use `terraform workspaces` or `terragrunt` (Task 4) for env/region splits.

3. **"Where do you store Terraform state?"**
   → S3 remote backend with native S3 locking (`use_lockfile`, no DynamoDB). Per-workspace keys isolate dev/staging/prod state.

4. **"How do you review Terraform changes?"**
   → Code review the .tf files, review terraform plan output, merge to main, CI/CD applies.

---

## Success Criteria

- [ ] bootstrap apply creates the S3 state bucket
- [ ] terraform init -backend-config=backend.hcl connects to S3
- [ ] terraform validate passes
- [ ] terraform workspace select dev|staging|prod works
- [ ] terraform plan shows ~20 resources for the selected workspace
- [ ] All outputs present (vpc_id, subnet_ids, environment, etc.)
- [ ] You can explain module reuse + workspace state isolation without notes

---

## Next Steps

→ [Task 4: Terragrunt](../task-4-terragrunt/README.md)
