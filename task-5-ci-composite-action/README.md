# Task 5: Reusable CI Composite Action — Automation at Scale

## Objective

Create a GitHub composite action that encapsulates `terragrunt plan && terragrunt apply` workflow. Enable any repo to use the action in their CI/CD pipeline without duplicating logic.

**Demonstration goal**: Show how to eliminate toil. Once defined, 50+ repos can use this action.

---

## The Problem Composite Actions Solve

### Without Composite Action (Anti-Pattern)

Every repo that uses Terraform needs to copy-paste the same workflow:

```yaml
# my-infra-repo/.github/workflows/deploy.yml
name: Deploy
on: [push]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - uses: hashicorp/setup-terraform@v2
    - run: terraform init
    - run: terraform plan
    - run: terraform apply

# another-repo/.github/workflows/deploy.yml
# IDENTICAL copy-paste (50+ times across org!)
```

**Problems**:
- 📋 Copy-paste across 50+ repos
- 🐛 Bug fix requires 50+ PRs
- 🔄 No consistency (each repo might tweak it)
- 🚀 Scaling becomes a nightmare

### With Composite Action (Chosen)

```yaml
# .github/actions/terragrunt-plan-apply/action.yaml
name: Terragrunt Plan & Apply
description: Run terragrunt plan and apply with locking

inputs:
  path: { description: "Working directory" }
  env: { description: "Environment (dev/staging/prod)" }
  var_file: { description: "Variable file" }

outputs:
  plan_output: { description: "Terraform plan summary" }

runs:
  using: composite
  steps:
  - uses: actions/checkout@v4
  - uses: hashicorp/setup-terraform@v2
  - run: terragrunt plan
  - run: terragrunt apply
```

Then in any repo:

```yaml
# any-repo/.github/workflows/deploy.yml
name: Deploy
on: [push]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: my-org/ci-actions/terragrunt-plan-apply@main
      with:
        path: live/prod/us-east-1/vpc
        env: prod
        var_file: prod.tfvars
```

**Benefits**:
- ✅ Single source of truth (action definition)
- ✅ Bug fix = 1 PR to action repo
- ✅ 50+ repos auto-updated (no resync needed)
- ✅ Consistent behavior across org

---

## Composite Action vs. Other Patterns

| Pattern | Complexity | Reusability | When to Use |
|---------|-----------|------------|------------|
| **Composite Action** | Low | High (org-wide) | Reusable, multi-step workflow |
| **Reusable Workflow** | Medium | Org-wide | Full job templates |
| **Docker Action** | High | Highest (public) | Complex logic, language-agnostic |
| **Script in Repo** | Very Low | None (copy-paste) | One-off, simple |

**Decision**: Composite action chosen because:
- ✅ Encapsulates multi-step terragrunt workflow
- ✅ Easy to share (copy action.yaml)
- ✅ No container build (instant, lightweight)
- ✅ Org-wide adoption without per-repo changes

---

## Action Architecture

### Inputs

```yaml
inputs:
  path:
    description: Working directory (e.g., live/dev/us-east-1/vpc)
    required: true
  env:
    description: Environment (dev, staging, prod)
    required: true
  var_file:
    description: Variable file for tfvars
    required: false
    default: "terraform.tfvars"
  aws_region:
    description: AWS region
    required: false
    default: "us-east-1"
  terraform_version:
    description: Terraform version
    required: false
    default: "1.5"
  terragrunt_version:
    description: Terragrunt version
    required: false
    default: "0.50"
```

### Outputs

```yaml
outputs:
  plan_output:
    description: Terraform plan summary
    value: ${{ steps.plan.outputs.summary }}
  apply_output:
    description: Terraform apply result
    value: ${{ steps.apply.outputs.result }}
  resources_created:
    description: Number of resources created
    value: ${{ steps.apply.outputs.changes }}
```

### Steps

1. **Setup**: Checkout, install tools
2. **Init**: `terragrunt init` (download providers, modules)
3. **Plan**: `terragrunt plan` (generate execution plan)
4. **Review**: Human reviews plan (for production)
5. **Apply**: `terragrunt apply` (provision resources)
6. **Report**: Post summary to PR

---

## File Structure

```
task-5-ci-composite-action/
├── README.md (this file)
├── action.yaml (action definition)
├── example-workflow.yaml (how to use in your repo)
└── INTEGRATION_GUIDE.md (org adoption guide)
```

---

## Action Definition (action.yaml)

The action encapsulates:

```yaml
name: Terragrunt Plan & Apply
description: |
  Runs terragrunt plan && terragrunt apply with proper locking,
  PR comments, and output parsing.

runs:
  using: composite
  steps:
  - name: Checkout code
    uses: actions/checkout@v4

  - name: Setup Terraform
    uses: hashicorp/setup-terraform@v2
    with:
      terraform_version: ${{ inputs.terraform_version }}

  - name: Setup Terragrunt
    shell: bash
    run: |
      TERRAGRUNT_VERSION=${{ inputs.terragrunt_version }}
      wget -q https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64
      chmod +x terragrunt_linux_amd64
      sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt

  - name: Configure AWS credentials
    uses: aws-actions/configure-aws-credentials@v2
    with:
      role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
      aws-region: ${{ inputs.aws_region }}

  - name: Terragrunt init
    shell: bash
    working-directory: ${{ inputs.path }}
    run: terragrunt init

  - name: Terragrunt plan
    id: plan
    shell: bash
    working-directory: ${{ inputs.path }}
    run: |
      terragrunt plan -out=tfplan > plan_output.txt 2>&1
      echo "summary=$(cat plan_output.txt)" >> $GITHUB_OUTPUT

  - name: Comment PR with plan
    if: github.event_name == 'pull_request'
    uses: actions/github-script@v6
    with:
      script: |
        const fs = require('fs');
        const plan = fs.readFileSync('plan_output.txt', 'utf8');
        github.rest.issues.createComment({
          issue_number: context.issue.number,
          owner: context.repo.owner,
          repo: context.repo.repo,
          body: `## Terragrunt Plan\n\`\`\`\n${plan}\n\`\`\``
        });

  - name: Terragrunt apply
    id: apply
    shell: bash
    working-directory: ${{ inputs.path }}
    run: |
      terragrunt apply tfplan
      echo "result=success" >> $GITHUB_OUTPUT
      echo "changes=$(terragrunt show tfplan -json | jq '.resource_changes | length')" >> $GITHUB_OUTPUT

  - name: Cleanup
    if: always()
    shell: bash
    working-directory: ${{ inputs.path }}
    run: |
      rm -f tfplan plan_output.txt
```

---

## Example Workflow Using Action

```yaml
# any-repo/.github/workflows/deploy.yml
name: Deploy Infrastructure

on:
  push:
    branches: [main]
    paths:
    - 'live/**'
    - 'modules/**'
  pull_request:
    branches: [main]

jobs:
  plan:
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
    - uses: my-org/ci-actions/terragrunt-plan-apply@main
      with:
        path: live/prod/us-east-1/vpc
        env: prod
        aws_region: us-east-1

  apply:
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    environment: production
    steps:
    - uses: my-org/ci-actions/terragrunt-plan-apply@main
      with:
        path: live/prod/us-east-1/vpc
        env: prod
        aws_region: us-east-1
```

---

## Key Concepts Demonstrated

### 1. Composite Actions

Composite actions combine multiple run steps into a reusable unit.

```yaml
runs:
  using: composite  # ← signals this is a composite action
  steps:
  - run: echo "Step 1"
  - run: echo "Step 2"
```

**Why composite?**
- ✅ Shell-based (no container, instant)
- ✅ Uses standard GitHub Actions ecosystem
- ✅ Easy to debug (each step visible in logs)
- ✅ Org-wide sharing via public repo

### 2. Inputs & Outputs

Actions expose inputs (caller provides) and outputs (action returns).

```yaml
inputs:
  path:
    description: Working directory
outputs:
  plan_output:
    value: ${{ steps.plan.outputs.summary }}
```

**Usage**:
```yaml
- uses: my-org/action@main
  with:
    path: live/prod/us-east-1  # ← input
  id: deploy

# Access outputs
- run: echo ${{ steps.deploy.outputs.plan_output }}  # ← output
```

### 3. Conditional Steps

Only run steps when conditions met:

```yaml
- name: Comment PR
  if: github.event_name == 'pull_request'  # Only on PRs
  run: ...

- name: Apply
  if: github.event_name == 'push'  # Only on push to main
  run: ...
```

### 4. Environment-Based Secrets

Restrict production deploys to approved runners:

```yaml
jobs:
  apply:
    environment: production  # ← requires approval
    steps:
    - uses: aws-actions/configure-aws-credentials@v2
      with:
        role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}  # Uses prod creds
```

### 5. Matrix Jobs (Bonus)

Deploy to multiple environments in parallel:

```yaml
strategy:
  matrix:
    environment: [dev, staging, prod]
    region: [us-east-1, eu-west-1]

steps:
- uses: my-org/ci-actions/terragrunt-plan-apply@main
  with:
    path: live/${{ matrix.environment }}/${{ matrix.region }}/vpc
    env: ${{ matrix.environment }}
```

---

## Adoption Guide (Org-Wide)

### For Platform Teams

1. **Store action in shared repo**:
   ```
   github.com/my-org/ci-actions/
   ├── .github/actions/terragrunt-plan-apply/
   │   └── action.yaml
   └── README.md
   ```

2. **Document usage**:
   ```yaml
   uses: my-org/ci-actions/terragrunt-plan-apply@main
   with:
     path: live/prod/us-east-1/vpc
     env: prod
   ```

3. **Version the action**:
   ```bash
   git tag v1.0.0
   # Callers use: my-org/ci-actions/terragrunt-plan-apply@v1.0.0
   ```

### For App Teams

1. **Use in your workflow**:
   ```yaml
   - uses: my-org/ci-actions/terragrunt-plan-apply@v1.0.0
     with:
       path: live/prod/us-east-1/vpc
       env: prod
   ```

2. **No need to copy-paste steps**
3. **Auto-get fixes** when platform team updates action

---

## Safety & Best Practices

### PR Review Before Apply

```yaml
- name: Plan
  run: terragrunt plan

- name: Approval Wait (Manual)
  if: github.event_name == 'pull_request'
  run: echo "Waiting for approval on PR before apply..."

- name: Apply
  if: github.event_name == 'push'
  run: terragrunt apply
```

### AWS IAM OIDC (No Long-Lived Credentials)

```yaml
- uses: aws-actions/configure-aws-credentials@v2
  with:
    role-to-assume: arn:aws:iam::ACCOUNT:role/GitHubActionsRole
    # ↑ No AWS_ACCESS_KEY stored; uses OIDC trust relationship
    aws-region: us-east-1
```

### State Locking

Terragrunt + S3 + DynamoDB handles state locking:

```bash
terragrunt init  # Acquires lock
terragrunt apply # Holds lock
# Lock released when done
```

Prevents concurrent applies that corrupt state.

---

## What's NOT Included

- **Complex approval workflows**: GitHub environments cover basic approval
- **Slack/email notifications**: Could add, not needed for demo
- **Multi-account deployments**: Single account demo; scales to multi-account
- **Rollback automation**: Manual rollback better for infrastructure
- **Advanced error handling**: Basic error output; production adds retries/backoff

---

## Interview Talking Points

1. **"Why composite action vs. reusable workflow?"**
   → Composite actions are lighter, better for tool-specific workflows. Reusable workflows for full job templates.

2. **"How do you prevent production deploys without review?"**
   → GitHub environment approval gate. PR → plan, human review → merge → auto-apply.

3. **"What if the action has a bug?"**
   → Update action.yaml in shared repo, all callers use latest. One fix, 50+ repos benefit.

4. **"How do you version the action?"**
   → Git tags. Callers pin version: `my-org/action@v1.0.0`. Breaking changes = new major version.

5. **"How many repos can use this?"**
   → Hundreds. Each repo's workflow includes it; GitHub runs independently per repo.

---

## Success Criteria

- [ ] action.yaml is valid (syntax checks)
- [ ] Example workflow shows proper usage
- [ ] Inputs and outputs are documented
- [ ] You can describe how to integrate this into a repo's workflow
- [ ] You understand composite vs. reusable workflow tradeoffs

---

## Next Steps

Congratulations! You've completed all 5 tasks. Ready for the walkthrough with Dima.

Quick review:
- ✅ Task 1 (ArgoCD): GitOps multi-env
- ✅ Task 2 (Crossplane): Cloud-agnostic abstractions
- ✅ Task 3 (Terraform): IaC foundations
- ✅ Task 4 (Terragrunt): Multi-env DRY
- ✅ Task 5 (CI Action): Automation at scale

You now have concrete examples across the full platform engineering stack. In the interview, you'll walk through each, explain the design choices, and discuss tradeoffs.

Good luck!
