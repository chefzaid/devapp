#!/bin/bash
set -e

# Default namespace
NAMESPACE="${1:-devapp}"

echo "Installing Istio..."
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

istioctl install --set profile=demo -y

echo "Labeling namespace $NAMESPACE for sidecar injection..."
kubectl create namespace $NAMESPACE || true
kubectl label namespace $NAMESPACE istio-injection=enabled --overwrite

echo "Istio installed and namespace labeled."
