#!/bin/bash
# Task 2: Crossplane Setup Script
# Installs Crossplane operator and applies XRD + Composition

set -e

echo "================================"
echo "Task 2: Crossplane Composition"
echo "================================"

# Check prerequisites
echo "Checking prerequisites..."
command -v kubectl >/dev/null || { echo "kubectl not found"; exit 1; }
command -v helm >/dev/null || { echo "helm not found"; exit 1; }

# Check cluster connectivity
echo "Checking cluster connectivity..."
kubectl cluster-info >/dev/null || { echo "Cannot connect to cluster"; exit 1; }

# Install Crossplane if not present
echo "Checking Crossplane installation..."
if ! kubectl get namespace crossplane-system &>/dev/null; then
  echo "Installing Crossplane operator..."
  helm repo add crossplane-stable https://charts.crossplane.io/stable
  helm repo update
  helm install crossplane crossplane-stable/crossplane \
    --namespace crossplane-system \
    --create-namespace \
    --wait \
    --timeout 5m

  echo "Waiting for Crossplane controller to be ready..."
  kubectl wait -n crossplane-system --for=condition=Ready pod -l app.kubernetes.io/name=crossplane --timeout=300s
else
  echo "Crossplane namespace already exists"
fi

# Create target namespace for application
echo "Creating application namespace..."
kubectl create namespace my-app --dry-run=client -o yaml | kubectl apply -f -

# Apply XRD (Composite Resource Definition)
echo "Applying XRD (Composite Resource Definition)..."
cd "$(dirname "$0")"
kubectl apply -f compositions/xrd.yaml

# Verify XRD created
echo "Waiting for XRD to be established..."
sleep 3
kubectl get xrd databases.database.example.com || echo "  (XRD may take a moment to appear)"

# Apply Composition
echo "Applying Composition..."
kubectl apply -f compositions/composition.yaml

# Verify Composition created
echo "Waiting for Composition to be established..."
sleep 3
kubectl get compositions -n crossplane-system || echo "  (Compositions may take a moment to appear)"

# Apply example claim
echo "Applying example DatabaseClaim..."
kubectl apply -f examples/claim.yaml

# Verify claim created
echo ""
echo "✓ Resources created:"
kubectl get databaseclaims -n my-app

# Monitor status
echo ""
echo "================================"
echo "Next Steps:"
echo "================================"
echo ""
echo "1. Watch claim provisioning (Ctrl-C to exit):"
echo "   kubectl get -w databaseclaims -n my-app"
echo ""
echo "2. Check composite resource status:"
echo "   kubectl get databases"
echo "   kubectl describe database my-app-db"
echo ""
echo "3. View Managed Resources created:"
echo "   kubectl get managed"
echo "   kubectl get configmaps -n crossplane-system | grep db"
echo ""
echo "4. See connection secret:"
echo "   kubectl get secrets -n crossplane-system | grep my-app-db"
echo ""
echo "================================"
echo "Architecture:"
echo "================================"
echo ""
echo "Claim (my-app-db) → XRD (Database) → Composition → Managed Resources"
echo ""
echo "Why Crossplane?"
echo "  ✓ Kubernetes-native (CRDs, like Deployments)"
echo "  ✓ Cloud-agnostic (same claim works for AWS/GCP/Azure)"
echo "  ✓ Separation: Teams use Claims, Platform team manages Compositions"
echo "  ✓ Secure: Platform team controls what's provisioned"
echo ""
echo "Key Concepts:"
echo "  • XRD: Custom resource schema (what teams claim)"
echo "  • Composition: Maps XRD to Managed Resources (how it's provisioned)"
echo "  • Managed Resource: Kubernetes representation of cloud resource"
echo "  • Claim: What application teams create (simple, no cloud knowledge)"
echo ""
echo "================================"
