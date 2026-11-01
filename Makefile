SHELL := bash

CLUSTER        := lab
ARGOCD_VERSION := v3.5.6
CONFIG_REPO    := ../eks-gitops-config
LAYERS_AWS     := network cluster

# up: kind, Calico, Argo CD (terraform/bootstrap, aplicado de verdade) e o root.yaml.
up:
	kind create cluster --name $(CLUSTER) --config kind/kind-config.yaml
	./scripts/instala-cni.sh
	cd terraform/bootstrap && terraform init -input=false && terraform apply -auto-approve
	kubectl apply -f $(CONFIG_REPO)/root.yaml

# Caminho da Etapa 1: o Argo CD vem do manifesto oficial, sem Terraform.
up-kubectl:
	kind create cluster --name $(CLUSTER) --config kind/kind-config.yaml
	./scripts/instala-cni.sh
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/$(ARGOCD_VERSION)/manifests/install.yaml
	kubectl -n argocd rollout status deployment/argocd-server --timeout=300s
	kubectl apply -f $(CONFIG_REPO)/root.yaml

# Apagar o cluster apaga junto o state do bootstrap, que passa a apontar para o nada.
down:
	kind delete cluster --name $(CLUSTER)
	rm -f terraform/bootstrap/terraform.tfstate terraform/bootstrap/terraform.tfstate.backup

verifica:
	kind get clusters
	docker ps --filter "name=$(CLUSTER)-" --format "{{.Names}}"

# Camadas AWS: só validação e testes. Nunca há apply nelas.
validate-aws:
	@for l in $(LAYERS_AWS); do \
	  echo "== $$l"; \
	  (cd terraform/$$l && terraform init -backend=false -input=false >/dev/null && terraform fmt -check && terraform validate && terraform test) || exit 1; \
	done

# Senha inicial do admin do Argo CD e acesso à interface em https://localhost:8080
argocd-senha:
	kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

argocd-ui:
	kubectl -n argocd port-forward svc/argocd-server 8080:443

.PHONY: up up-kubectl down verifica validate-aws argocd-senha argocd-ui

# Políticas em Rego: testes unitários e conftest sobre o plano real da camada network (offline).
policy:
	opa test policy/
	cd terraform/network && terraform init -backend=false -input=false >/dev/null && terraform plan -input=false -out=network.tfplan >/dev/null && terraform show -json network.tfplan > plan.json
	conftest test terraform/network/plan.json -p policy

.PHONY: policy

# Trivy só no código próprio (sem os caches de módulos e charts); as exceções estão em .trivyignore.
scan:
	trivy config terraform --skip-dirs "**/.helm,**/.terraform" --severity HIGH,CRITICAL --ignorefile .trivyignore --exit-code 1

.PHONY: scan

# Observabilidade (Etapa 5). A senha do Grafana é gerada pelo chart; não existe uma padrão.
grafana-senha:
	kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d; echo

grafana-ui:
	kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80

prometheus-ui:
	kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090

alertmanager-ui:
	kubectl -n monitoring port-forward svc/kube-prometheus-stack-alertmanager 9093:9093

.PHONY: grafana-senha grafana-ui prometheus-ui alertmanager-ui
