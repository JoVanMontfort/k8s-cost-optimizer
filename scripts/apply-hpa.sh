#!/bin/bash
# Usage: ./apply-hpa.sh <namespace> <deployment>

NAMESPACE="$1"
DEPLOYMENT="$2"
kubectl apply -f manifests/hpa-$DEPLOYMENT.yaml -n "$NAMESPACE"
echo "HPA applied for $DEPLOYMENT in $NAMESPACE. Checking status..."
kubectl get hpa -n "$NAMESPACE"