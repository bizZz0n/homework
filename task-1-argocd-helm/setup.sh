#!/bin/bash
# Task 1: ArgoCD + Helm Setup Script
# Deploys ArgoCD and applies the ApplicationSet

set -e

echo "================================"
echo "Task 1: ArgoCD + Helm GitOps"
echo "================================"

# Check prerequisites
echo "Checking prerequisites..."
command -v kubectl >/dev/null || { echo "kubectl not found"; exit 1; }
command -v helm >/dev/null || { echo "helm not found"; exit 1; }

# Check cluster connectivity
echo "Checking cluster connectivity..."
kubectl cluster-info >/dev/null || { echo "Cannot connect to cluster"; exit 1; }

# Install ArgoCD if not present
echo "Checking ArgoCD installation..."
if ! kubectl get namespace argocd &>/dev/null; then
  echo "Installing ArgoCD..."
  kubectl create namespace argocd
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  echo "Waiting for ArgoCD server to be ready (this may take 1-2 minutes)..."
  kubectl wait -n argocd --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server --timeout=300s
else
  echo "ArgoCD namespace already exists"
fi

# Create target namespaces
echo "Creating target namespaces..."
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f -

# Apply ApplicationSet
echo "Applying ApplicationSet..."
cd "$(dirname "$0")"
kubectl apply -f argocd/applicationset.yaml

# Verify ApplicationSet created Applications
echo ""
echo "Waiting for Applications to be created..."
sleep 5

echo ""
echo "✓ Applications created:"
kubectl get applications -n argocd || echo "  (Applications may take a moment to appear)"

# Get ArgoCD password
echo ""
echo "================================"
echo "Next Steps:"
echo "================================"
echo ""
echo "1. Port forward to ArgoCD UI:"
echo "   kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo ""
echo "2. Login to https://localhost:8080"
echo "   User: admin"
echo "   Password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""
echo "3. Verify Applications:"
echo "   kubectl get applications -n argocd"
echo "   kubectl get pods -n dev"
echo "   kubectl get pods -n staging"
echo ""
echo "================================"
echo "Architecture Notes:"
echo "================================"
echo ""
echo "ApplicationSet Generators:"
echo "  - List: Multiple environments (dev, staging)"
echo "  - Helm: Base values + per-env overrides (values-{env}.yaml)"
echo "  - Sync Policy: automated (prune + selfHeal)"
echo ""
echo "Why ApplicationSet?"
echo "  ✓ DRY: Single manifest for both environments"
echo "  ✓ Scalable: Add new env with one list element"
echo "  ✓ Industry standard for multi-env GitOps"
echo ""
echo "Helm Strategy (DRY):"
echo "  ✓ values.yaml: Shared base (all keys defined)"
echo "  ✓ values-dev.yaml: Dev overrides (replicas, images, logs)"
echo "  ✓ values-staging.yaml: Staging overrides (HA config, prod images)"
echo ""
echo "================================"
