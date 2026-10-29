#!/usr/bin/env bash
# Instala o Calico no kind e espera os nós ficarem Ready.
set -euo pipefail

CALICO_VERSION="${CALICO_VERSION:-v3.33.0}"

kubectl apply -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"
kubectl -n kube-system rollout status daemonset/calico-node --timeout=300s
kubectl wait --for=condition=Ready nodes --all --timeout=300s
