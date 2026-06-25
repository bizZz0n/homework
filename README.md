# Platform Engineering Walkthrough — Complete Exercise

**Goal**: Demonstrate senior-level platform engineering skills across GitOps, IaC, infrastructure composition, and CI/CD automation.

**Structure**: 5 tasks, designed as a focused day's work (~6-8 hours). Build as you normally work; minimal polish, maximum reasoning.

---

## Overview: Why This Stack?

### Technology Choices & Tradeoffs

| Task | Tool | Why | Not |
|------|------|-----|-----|
| **1. GitOps** | ArgoCD + Helm | Declarative, operator-driven, cluster-native. Industry standard for K8s GitOps. | Flux: equally valid, fewer CRDs. Kustomize: less powerful templating. |
| **2. Composition** | Crossplane | Kubernetes-native claim/composition model; cloud-agnostic abstractions. Shows deep K8s knowledge. | Helm charts: no abstraction layer. CloudFormation: AWS-only, not portable. |
| **3. Networking** | Terraform + AWS modules | Standard IaC; public modules reduce boilerplate; HCL readable. | Pulumi: valid, adds language overhead. CDK: more code, less declarative. |
| **4. Multi-env** | Terragrunt | DRY folder hierarchy; live demo promotion flow; handles env/region/component structure. | Plain Terraform: massive duplication. Helm: not for infra. |
| **5. Reusable CI** | GitHub Composite Action | Org-wide reuse; integrates with any workflow; encapsulates terragrunt-plan-apply pattern. | Shell script: not reusable. Docker action: overkill for this. |

### Architecture Philosophy

- **Layered abstractions**: Crossplane (claims) → Terraform (resources) → Terragrunt (env mgmt)
- **Separation of concerns**: GitOps handles apps; Terraform handles infra; Terragrunt handles promotion
- **Minimal manual toil**: Composite action + Terragrunt reduce copy-paste 80%+
- **Real constraints**: No cloud account needed for Crossplane demo; Terraform uses public modules

---

## Tasks at a Glance

### Task 1: ArgoCD ApplicationSets & Helm (GitOps)
**What**: Deploy a sample app across dev/staging using ApplicationSets + environment-specific Helm values.

**Why**: Shows GitOps maturity—no kubectl apply, no manual drifts. ApplicationSets handle multi-env from single manifest.

**Key Concepts**:
- Single ApplicationSet → multi-env apps
- Shared Helm chart + per-env `values-dev.yaml`, `values-staging.yaml`
- ArgoCD syncs state, enforces declarative config

**Deliverable**: Running sample app on minikube with ArgoCD watching git.

**See**: [task-1-argocd-helm/README.md](task-1-argocd-helm/README.md)

---

### Task 2: Crossplane Resource Composition (IaC Abstraction)
**What**: Define a Crossplane Composite Resource (XRD + composition); claim it; show custom resource model.

**Why**: Demonstrates cloud-agnostic abstraction layer. You write claims, Crossplane provisions infra. Shows architectural depth.

**Key Concepts**:
- XRD: your custom resource (e.g., `Database`)
- Composition: backing implementation (AWS RDS, GCP Cloud SQL, etc.)
- Claims: dev teams use claims, don't see provisioning details
- No cloud creds needed for demo (in-cluster Crossplane provider)

**Deliverable**: Working composition in cluster; claim → resource flow demonstrated.

**See**: [task-2-crossplane/README.md](task-2-crossplane/README.md)

---

### Task 3: Terraform AWS Networking (IaC Foundation)
**What**: Provision VPC + subnets + routing using Terraform + public `terraform-aws-modules/vpc`.

**Why**: Baseline IaC skill. Module reuse shows pragmatic approach (not reinventing).

**Key Concepts**:
- HCL: readable, declarative
- Public modules: less boilerplate, battle-tested
- Parameterized for reuse (cidr, azs, etc.)
- Output critical resources for Task 4

**Deliverable**: Terraform code, tfvars, outputs. Plan reviewable (no actual apply required).

**See**: [task-3-terraform-aws/README.md](task-3-terraform-aws/README.md)

---

### Task 4: Terragrunt Multi-Env Promotion (DRY Infrastructure)
**What**: Folder hierarchy (dev/staging/prod × region × component). Live demo: `dev → staging` promotion flow.

**Why**: Real pain point—Terraform alone explodes with duplication. Terragrunt solves DRY at scale. Shows ops thinking.

**Key Concepts**:
- `live/` = environment definitions
- `modules/` = shared Terraform
- `terragrunt.hcl` = DRY inclusion, backend config, dependency wiring
- Promotion: copy `live/dev/...` → `live/staging/...`, change vars, apply

**Deliverable**: Live folder structure; runnable `terragrunt plan` for promotion scenario.

**See**: [task-4-terragrunt/README.md](task-4-terragrunt/README.md)

---

### Task 5: Reusable CI Composite Action (Automation at Scale)
**What**: GitHub composite action encapsulating `terragrunt plan && terragrunt apply` flow.

**Why**: Eliminates copy-paste in workflows. Any repo can use `terragrunt-plan-apply` action without reinventing.

**Key Concepts**:
- Composite actions: workflow-as-code reusable building blocks
- Inputs: path, env, var-file
- Outputs: plan summary, apply status
- Integrates with any CI workflow

**Deliverable**: Action definition + example workflow using it.

**See**: [task-5-ci-composite-action/README.md](task-5-ci-composite-action/README.md)

---

## How to Run (Quick Start)

### Prerequisites
```bash
# Install tools
brew install terraform terragrunt helm argocd crossplane-cli

# Start minikube (for Tasks 1, 2)
minikube start

# AWS creds optional (Tasks 3-4 plan only, no apply)
export AWS_REGION=us-east-1
```

### Task-by-Task Execution

```bash
# Task 1: ArgoCD + Helm
cd task-1-argocd-helm
./setup.sh
kubectl port-forward -n argocd svc/argocd-server 8080:443
# Open https://localhost:8080, login, observe ApplicationSet syncing

# Task 2: Crossplane
cd ../task-2-crossplane
./setup.sh
kubectl apply -f examples/claim.yaml
kubectl get databases  # Watch resource provisioning

# Task 3: Terraform (plan only)
cd ../task-3-terraform-aws
terraform plan

# Task 4: Terragrunt (plan only)
cd ../task-4-terragrunt
terragrunt plan-all --terragrunt-working-dir live/dev

# Task 5: CI Action (reference only)
cd ../task-5-ci-composite-action
# See example-workflow.yaml for how to use in GitHub Actions
```

---

## Decision Log: Why These Specific Choices?

### ArgoCD vs. Flux
- **ArgoCD chosen**: Simpler learning curve, richer UI, better ApplicationSets support.
- **Tradeoff**: Flux is more GitOps-purist (reconciliation-only), less opinionated.
- **Why ArgoCD for interview**: Shows you can navigate both, but ArgoCD's UI + ApplicationSets is more demonstrable.

### Crossplane vs. Helm Charts
- **Crossplane chosen**: Demonstrates abstraction layer thinking. Claim/composition model is enterprise-level.
- **Helm tradeoff**: Easier to learn, but doesn't show architectural depth.
- **Why Crossplane**: Senior role expects cloud-abstraction thinking, not just packaging.

### Terraform + Public Modules vs. From-Scratch HCL
- **Public modules chosen**: Real teams use them. Reinventing VPC is busywork.
- **Tradeoff**: You could write raw HCL to show "I know how," but it's not how experts actually work.
- **Why modules**: Shows pragmatism, judgment, and code reuse thinking.

### Terragrunt for Multi-Env vs. Terraform Workspaces
- **Terragrunt chosen**: Folder hierarchy is more scalable, easier to visualize, allows region/component splits.
- **Workspaces tradeoff**: Simpler conceptually, but scales poorly (no component separation).
- **Why Terragrunt**: Real enterprise pattern. Shows you've thought about sprawl.

### GitHub Composite Action vs. Reusable Workflow
- **Composite action chosen**: Finer-grained reuse, better for individual tool steps.
- **Reusable workflow tradeoff**: Could work, but composite actions are more flexible for multi-repo use.
- **Why composite**: Shows understanding of both patterns; composite is the building block.

---

## What You'll Demonstrate in the Interview

1. **Task 1 (ArgoCD)**: GitOps maturity, multi-env declarative config, ApplicationSets pattern
2. **Task 2 (Crossplane)**: Abstraction layer thinking, cloud-agnostic design, claim/composition model
3. **Task 3 (Terraform)**: Pragmatic IaC, module reuse, HCL fluency
4. **Task 4 (Terragrunt)**: DRY thinking at scale, multi-env folder hierarchy, promotion workflows
5. **Task 5 (CI Action)**: Workflow automation, reusable building blocks, elimination of toil

**Interviewer asks**: "Walk us through Task 4's promotion flow."
**You answer**: "Show terragrunt plan, explain DRY dedup, demo copying dev → staging, show apply."

---

## What's NOT in Scope (and Why)

- **Helm charts from scratch**: Use a simple one; the focus is GitOps, not templating.
- **AWS account required**: Terraform plans work without apply. Crossplane demo is in-cluster only.
- **Complex networking**: VPC + subnets + routing. No security groups deep-dive; README explains tradeoffs.
- **Polished UI**: Working implementation > polish. Interview cares about reasoning, not theme.
- **Full CI/CD pipeline**: Action is reusable; one example workflow shows integration.

---

## Repository Structure

```
.
├── README.md (this file)
├── task-1-argocd-helm/
│   ├── README.md
│   ├── sample-app/ (Helm chart)
│   ├── argocd/ (ApplicationSet, setup)
│   └── setup.sh
├── task-2-crossplane/
│   ├── README.md
│   ├── compositions/
│   ├── examples/
│   └── setup.sh
├── task-3-terraform-aws/
│   ├── README.md
│   ├── *.tf files
│   └── terraform.tfvars
├── task-4-terragrunt/
│   ├── README.md
│   ├── live/ (env hierarchy)
│   ├── modules/ (shared Terraform)
│   └── terragrunt.hcl
├── task-5-ci-composite-action/
│   ├── README.md
│   ├── action.yaml
│   └── example-workflow.yaml
└── DECISIONS.md (extended architecture decisions)
```

---

## How to Use This for the Interview

1. **Before the call**: Know each task cold. Be ready to explain why you chose each tool.
2. **During the call**: Screenshare, walk through Task 1 (ArgoCD running), then Task 4 (promotion flow). Have terraform plan output ready.
3. **Be ready for**: "What would you do differently?" or "How does this scale to 100 teams?" Answer honestly; show tradeoffs.
4. **Bonus points**: Explain Crossplane to the interviewer. Few candidates understand it deeply.

---

## Questions to Answer Before You Start

If you get stuck on any task, these questions guide the decision:

- **Why this tool over the alternative?** (Covered in decision log above)
- **What's the failure mode?** (e.g., ArgoCD loses cluster connection → manual sync needed)
- **How does it scale?** (e.g., Terragrunt scales across 1000s of envs; ApplicationSets scale to 100+ apps)
- **What's not included?** (e.g., GitOps doesn't auto-revert manual changes; Terraform doesn't validate business logic)

---

## Success Criteria

- [ ] Task 1: ArgoCD running, ApplicationSet syncing app to dev + staging
- [ ] Task 2: Crossplane composition works, claim provisioning visible
- [ ] Task 3: Terraform plan runs, outputs VPC ID + subnets
- [ ] Task 4: Terragrunt plan-all runs; you can describe the dev → staging promotion
- [ ] Task 5: Action defined; example workflow shows how teams would use it
- [ ] README + code comments explain all major decisions
- [ ] You can talk through any task in 2-3 minutes without notes

---

## Next Steps

1. Start with Task 1 (shortest, most visual).
2. Move to Task 2 (deepest conceptually).
3. Tasks 3-4 are foundational; build in order.
4. Task 5 ties it all together.

Each task has a dedicated README with setup instructions and architecture notes. Open each and start building.

Good luck. Ship it.
