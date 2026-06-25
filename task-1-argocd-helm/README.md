# Task 1: ArgoCD ApplicationSets & Helm — GitOps Multi-Env Deployment

## Objective

Deploy a sample application across **dev** and **staging** environments using ArgoCD and Helm, with a single ApplicationSet managing both environments from different git branches/overlay patterns.

**Demonstration goal**: Show that ArgoCD watches git; any config change auto-syncs without kubectl apply.

---

## Architecture Decisions

### Why ApplicationSets?

**Traditional ArgoCD approach**:
```yaml
# Separate Application per env (brittle, duplication)
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sample-app-dev
spec:
  source:
    repoURL: https://github.com/user/app
    path: charts/sample-app
    helm:
      valuesFiles:
      - values-dev.yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sample-app-staging
spec:
  # ... mostly repeated ...
```

**ApplicationSet approach** (chosen):
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: sample-app
spec:
  generators:
  - list:
      elements:
      - env: dev
        replicas: 1
      - env: staging
        replicas: 2
  template:
    spec:
      source:
        helm:
          valuesFiles:
          - values-{{env}}.yaml
```

**Why ApplicationSet**:
- ✅ **Single manifest** handles both envs (DRY)
- ✅ **Easy to scale** to 10+ envs (just add list element)
- ✅ **Flexible generators** (list, git files, matrix, cluster discovery)
- ✅ **Industry standard** (all major shops use ApplicationSets at scale)

**Tradeoff**: ApplicationSets add a layer; simpler projects might use separate Applications.

---

### Why Helm Over Kustomize?

| Feature | Helm | Kustomize |
|---------|------|-----------|
| **Templating** | Go templates, built-in functions | Strategic merge + overlays |
| **Reusability** | Charts as packages | Overlays per variant |
| **Complexity** | Steeper learning curve | Shallower, more transparent |
| **Ecosystem** | 1000s of public charts | Smaller ecosystem |

**Decision**: Helm chosen because:
- ApplicationSets work cleanly with Helm's `valuesFiles` pattern
- Shows you can manage templating complexity (senior skill)
- Per-env `values-{env}.yaml` is cleaner than Kustomize overlays for this use case

---

### Helm Values Structure (DRY Strategy)

```
sample-app/
├── Chart.yaml
├── values.yaml              (shared: app name, basic config)
├── values-dev.yaml         (overlay: 1 replica, dev image tag)
├── values-staging.yaml     (overlay: 2 replicas, staging image tag)
└── templates/
    ├── deployment.yaml
    ├── service.yaml
    └── configmap.yaml
```

**Why this structure**:
- ✅ `values.yaml` has all keys; dev/staging only override what differs
- ✅ Clear diff view (what changes per env)
- ✅ Scales to N envs easily
- ✅ No duplication

**Per-env values** (not full charts):
```yaml
# values-dev.yaml
replicaCount: 1
image:
  tag: dev-latest
logLevel: debug

# values-staging.yaml
replicaCount: 2
image:
  tag: staging-v1.0.0
logLevel: info
```

---

## Setup & Execution

### Prerequisites

```bash
# Install ArgoCD (stable channel)
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for server ready
kubectl wait -n argocd --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server --timeout=300s

# Get initial password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Deploy ApplicationSet

```bash
# Apply ApplicationSet (creates 2 Applications: dev + staging)
kubectl apply -f argocd/applicationset.yaml

# Verify Applications created
kubectl get applications -n argocd

# Output:
# NAME                      SYNC STATUS   HEALTH STATUS
# sample-app-dev            Synced        Healthy
# sample-app-staging        Synced        Healthy
```

### Access UI & Verify

```bash
# Port forward to ArgoCD server
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Login
# URL: https://localhost:8080
# User: admin
# Pass: (from initial secret above)
```

**In UI, you'll see**:
- ApplicationSet → sample-app
- Generated Applications → sample-app-dev, sample-app-staging
- Deployment pods in respective namespaces

---

## Key Concepts Demonstrated

### 1. Single Source of Truth (Git)

ApplicationSet watches the git repo. Change `values-dev.yaml` → ArgoCD syncs automatically.

```bash
# Simulate change
echo "# Updated" >> values-dev.yaml
git add . && git commit -m "Update dev config"
git push

# ArgoCD detects → auto-syncs (no kubectl needed)
# Watch in UI: Sync Status → Synced
```

### 2. Environment Parity + Divergence

Same app code, different config per env:
- `dev`: 1 replica, verbose logging, latest images
- `staging`: 2 replicas, info logging, released images

Helm values handle this cleanly. No branching, no duplicate Deployments.

### 3. ApplicationSet Generators

This example uses `list` generator (simplest). Other patterns:

```yaml
# Git files generator (one dir per env)
generators:
- git:
    repoURL: https://github.com/user/app
    path: "apps/*"
    
# Cluster discovery (deploy to all clusters)
generators:
- clusters: {}

# Matrix (combine multiple generators)
generators:
- matrix:
    generators:
    - git: ...
    - list: ...
```

**Why list for this demo**: Simplest, most predictable. In real world, you'd use git files or matrix for 50+ envs.

---

## Failure Modes & Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| **Applications not created** | ApplicationSet has syntax error | Check `kubectl describe applicationset sample-app` |
| **Sync stuck (red)** | Values file missing or malformed | Check Helm render: `helm template` locally |
| **Pods not running** | Image pull error (dev-latest doesn't exist) | Use valid image; see values-{env}.yaml |
| **ArgoCD loses cluster** | Network issue or creds expired | Manual sync needed; reconfigure credentials |

---

## What's NOT Included (and Why)

- **Private git repo**: Uses public repo; configure `repository` credential if private
- **Image pull secrets**: Assumes public images; add to values if needed
- **Ingress**: Service only; Ingress pattern similar
- **RBAC/OIDC**: ArgoCD defaults sufficient for demo
- **Notifications**: Could add; not needed for walkthrough

---

## Interview Talking Points

1. **"Why ApplicationSets?"** → DRY, scalable, industry standard
2. **"How do you promote dev → staging?"** → Copy values, change image tag + replicas, push, ArgoCD syncs
3. **"What if someone kubectl apply by hand?"** → ArgoCD detects drift, shows it in UI, can auto-correct or alert
4. **"How many envs can this handle?"** → Hundreds; ApplicationSet generators scale linearly

---

## Success Criteria

- [ ] ArgoCD running, UI accessible
- [ ] ApplicationSet creates 2 Applications
- [ ] Both apps are "Synced" and "Healthy"
- [ ] Pods running in dev and staging namespaces
- [ ] You can describe the git → sync flow without notes

---

## Next Steps

→ [Task 2: Crossplane](../task-2-crossplane/README.md)
