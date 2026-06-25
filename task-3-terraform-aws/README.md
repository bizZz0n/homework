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
├── main.tf (VPC module + resources)
├── variables.tf (input variables, flexible)
├── outputs.tf (export VPC ID, subnet IDs, etc.)
├── terraform.tfvars (default values)
├── terraform.lock.hcl (dependency lock, commit to git)
└── .gitignore (excludes terraform state, secrets)
```

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

### Validate & Plan (No Apply)

```bash
cd task-3-terraform-aws

# Initialize Terraform (download provider, modules)
terraform init

# Validate syntax
terraform validate

# Generate plan (shows what would be created)
terraform plan -out=tfplan

# Review plan output
# Expected: ~20 resources (VPC, subnets, NAT gateways, route tables, etc.)
```

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
- ✅ **Must be stored remotely** (S3 backend) in real projects

**For this demo**: Local state is fine. Real teams use S3 + DynamoDB.

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

- **Remote state**: Uses local state; production teams use S3 + DynamoDB
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
   → Remote backend (S3 + DynamoDB). Local state for demo; production uses remote with locking.

4. **"How do you review Terraform changes?"**
   → Code review the .tf files, review terraform plan output, merge to main, CI/CD applies.

---

## Success Criteria

- [ ] terraform init runs
- [ ] terraform validate passes
- [ ] terraform plan shows ~20 resources
- [ ] All outputs present (vpc_id, subnet_ids, etc.)
- [ ] You can explain module reuse benefit without notes

---

## Next Steps

→ [Task 4: Terragrunt](../task-4-terragrunt/README.md)
