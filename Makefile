SHELL := bash

CLUSTER        := lab
ARGOCD_VERSION := v3.5.6
CONFIG_REPO    := ../eks-gitops-config

# Etapa 1: tudo por kubectl. Na Etapa 2 o Argo CD passa a vir da camada terraform/bootstrap.
up:
	kind create cluster --name $(CLUSTER) --config kind/kind-config.yaml
	./scripts/instala-cni.sh
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/$(ARGOCD_VERSION)/manifests/install.yaml
	kubectl -n argocd rollout status deployment/argocd-server --timeout=300s
	kubectl apply -f $(CONFIG_REPO)/root.yaml

down:
	kind delete cluster --name $(CLUSTER)

verifica:
	kind get clusters
	docker ps --filter "name=$(CLUSTER)-" --format "{{.Names}}"

# Senha inicial do admin do Argo CD e acesso à interface em https://localhost:8080
argocd-senha:
	kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

argocd-ui:
	kubectl -n argocd port-forward svc/argocd-server 8080:443

.PHONY: up down verifica argocd-senha argocd-ui
