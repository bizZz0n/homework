# Task 2: Crossplane Resource Composition — Cloud-Agnostic Abstractions

## Objective

Demonstrate **cloud-agnostic infrastructure abstraction** using Crossplane. Define a Composite Resource Definition (XRD) + Composition, then claim it. Show how ops teams provision infrastructure without knowing underlying cloud details.

**Demonstration goal**: Claim → Crossplane provisions resource. Understand abstraction layers.

---

## Architecture & Philosophy

### The Problem Crossplane Solves

**Without abstraction** (teams write Terraform):
```hcl
# Team A (needs database)
resource "aws_rds_instance" "prod_db" {
  engine         = "postgres"
  instance_class = "db.t3.large"
  allocated_storage = 100
  # ... 20 more parameters ...
}

# Team B (different cloud, rewrites everything)
resource "google_sql_database_instance" "prod_db" {
  # Completely different syntax, different params
  # Teams repeat; no standardization
}

# Team C (Azure)
resource "azurerm_mssql_server" "prod_db" {
  # Yet another syntax
}
```

**With Crossplane abstraction**:
```yaml
# All teams use the same claim, Crossplane handles backing cloud
apiVersion: database.example.com/v1alpha1
kind: Database
metadata:
  name: my-app-db
spec:
  engine: postgres
  size: large
  backups: enabled
```

**Why this matters**:
- ✅ **Consistency**: All teams use same API, regardless of cloud
- ✅ **Portability**: Switch clouds (AWS → GCP) by changing composition, not claims
- ✅ **Security**: Teams can't over-provision or access restricted parameters
- ✅ **Self-service**: Developers claim resources; platform team controls cost/security

---

### Crossplane Concepts

#### 1. **Managed Resources** (MRs)
Kubernetes-native representation of cloud resources.
```yaml
apiVersion: rds.aws.upbound.io/v1beta1
kind: Instance
metadata:
  name: prod-db
spec:
  forProvider:
    engine: postgres
    dbInstanceClass: db.t3.large
    allocatedStorage: 100
```
↑ This is a Managed Resource. You could apply it directly, but it's complex.

#### 2. **Composite Resource Definition** (XRD)
Define your custom resource (like a CRD, but for infrastructure).
```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: databases.database.example.com
spec:
  group: database.example.com
  names:
    kind: Database
    plural: databases
  claimNames:
    kind: DatabaseClaim
    plural: databaseclaims
  # ... spec fields you want teams to use ...
```

#### 3. **Composition**
Map XRD → backing Managed Resources.
```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: database-composition
spec:
  compositeTypeRef:
    apiVersion: database.example.com/v1alpha1
    kind: Database
  resources:
  - name: rds-instance
    base:
      apiVersion: rds.aws.upbound.io/v1beta1
      kind: Instance
    patches:
    - fromFieldPath: "spec.engine"
      toFieldPath: "spec.forProvider.engine"
```

#### 4. **Claim** (Consumed by App Teams)
What developers actually use.
```yaml
apiVersion: database.example.com/v1alpha1
kind: DatabaseClaim
metadata:
  name: my-app-db
  namespace: my-app
spec:
  engine: postgres
  size: large
  backups: enabled
```
↑ Simple, clean, no cloud knowledge needed.

---

### Why Crossplane Over Alternatives?

| Tool | Strength | Weakness | When to Use |
|------|----------|----------|------------|
| **Crossplane** | Cloud-agnostic, Kubernetes-native | Steeper learning curve | Multi-cloud, platform abstractions, self-service |
| **Helm + Terraform** | Familiar, modular | Not declarative for infra, schema loose | Simple provisioning, single-cloud |
| **CloudFormation** | AWS-native, powerful | AWS-only, verbose syntax | AWS-only infrastructure |
| **Pulumi** | Programmatic, flexible | Language-dependent, less declarative | Complex multi-cloud logic |

**Decision**: Crossplane chosen because:
- ✅ Kubernetes-native (CRD-based, fits with ArgoCD from Task 1)
- ✅ Cloud-agnostic (demonstrates architectural thinking)
- ✅ Claims separate concerns (developers ↔ platform team)
- ✅ Real enterprise pattern (heavily used at scale)

---

## Setup & Execution

### Prerequisites

```bash
# Install Crossplane operator
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update
helm install crossplane crossplane-stable/crossplane \
  --namespace crossplane-system \
  --create-namespace \
  --wait

# Wait for Crossplane to be ready
kubectl wait -n crossplane-system --for=condition=Ready pod -l app.kubernetes.io/name=crossplane --timeout=300s
```

### Deploy XRD + Composition

```bash
# Apply our custom resource definition
kubectl apply -f compositions/xrd.yaml

# Apply composition (maps XRD to backing resources)
kubectl apply -f compositions/composition.yaml

# Verify XRD was created
kubectl get xrd
```

### Create a Claim

```bash
# Create namespace for application
kubectl create namespace my-app

# Claim a database
kubectl apply -f examples/claim.yaml

# Watch resource provisioning
kubectl get databases
kubectl get databaseclaims -n my-app
kubectl describe databaseclaim my-app-db -n my-app
```

### Verify Resources Created

```bash
# See what Managed Resources Crossplane created
kubectl get managed

# Detailed view
kubectl describe managed
```

---

## Key Concepts Demonstrated

### 1. Abstraction Layers

```
Application Team (Claims)
        ↓
   Crossplane XRD
        ↓
   Composition (Pattern)
        ↓
Managed Resources (AWS, GCP, Azure)
        ↓
   Actual Cloud Infrastructure
```

**Why layered**:
- Team A writes claim (simple, no cloud knowledge)
- Platform team owns composition (security, cost control)
- Crossplane translates (cloud-agnostic)

### 2. Composability

Single composition can manage multiple resources. Example:
```yaml
resources:
- name: rds-instance
  base: RDS Instance resource
- name: security-group
  base: Security Group resource
- name: subnet-group
  base: DB Subnet Group resource
- name: iam-role
  base: IAM Role for backups
- name: secrets-store
  base: AWS Secrets Manager entry
```

**Result**: One claim creates 5 interconnected resources automatically.

### 3. Parameterization via Patches

Map claim fields to resource fields:
```yaml
- fromFieldPath: "spec.size"
  toFieldPath: "spec.forProvider.dbInstanceClass"
  transforms:
  - type: map
    map:
      small: db.t3.micro
      large: db.t3.large
      xlarge: db.r5.2xlarge
```

**Result**: Team claims `size: large`; Crossplane translates to cloud-specific class.

### 4. Multi-Cloud Portability

Same claim, different composition:
```
If composition → AWS: claim creates RDS
If composition → GCP: claim creates Cloud SQL
If composition → Azure: claim creates Cosmos DB
```

Change one composition; all claims auto-update.

---

## Failure Modes & Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| **XRD not created** | Schema syntax error | Check `kubectl describe xrd databases` |
| **Composition not matching** | Composite type reference wrong | Verify `compositeTypeRef` matches XRD name |
| **Resource status "Syncing"** | Provisioning in progress | Wait; watch with `kubectl get -w` |
| **Resource status "False"** | Configuration error | Check `kubectl describe` for detailed error |
| **Provider not installed** | aws-upbound provider missing | Install with `helm install` or kubectl apply |

---

## What's NOT Included (and Why)

- **Cloud provider setup**: Uses built-in Crossplane providers; no AWS credentials needed
- **Advanced networking**: Focus is on abstraction, not cloud-specific features
- **Multi-cloud composition**: Single AWS example; pattern extends to multi-cloud
- **Policy engine**: Could add Kyverno for cost gates; not needed for demo
- **Observability**: Focus is on pattern; logging/metrics not included

---

## Interview Talking Points

1. **"What's the difference between an XRD and a Composition?"**
   → XRD = your custom resource schema (what teams claim). Composition = backing implementation (how Crossplane provisions).

2. **"Why use Crossplane instead of Helm + Terraform?"**
   → Crossplane gives abstraction layers. Teams don't need cloud knowledge. Platform team controls cost/security via composition.

3. **"How does this scale to multi-cloud?"**
   → Same XRD + claims. Different composition per cloud. Swap compositions without touching claims.

4. **"What's a real use case?"**
   → Platform team: "We support AWS + GCP. Teams claim Database. If team moves clouds, no claim changes needed. Composition handles it."

5. **"How do you handle secrets (like DB passwords)?"**
   → Crossplane can write connection strings to Kubernetes Secrets. Applications read from Secret.

---

## Success Criteria

- [ ] XRD created successfully
- [ ] Composition deployed
- [ ] Claim created
- [ ] Managed Resources visible (`kubectl get managed`)
- [ ] You can explain claim → composition → MR flow without notes

---

## Next Steps

→ [Task 3: Terraform AWS](../task-3-terraform-aws/README.md)
