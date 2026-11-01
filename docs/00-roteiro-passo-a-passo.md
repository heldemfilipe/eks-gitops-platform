# 00 - Roteiro passo a passo (Terraform 2, modo local e sem AWS)

Adaptação do roteiro "Terraform 2: plataforma EKS com GitOps, observabilidade e guardrails" ao que já existe nos
projetos anteriores (`terraform-aws-foundation` e `orders-api`) e a uma regra nova:

> **Nada deste projeto é aplicado na AWS.** Sem free tier e sem querer risco de cobrança, o projeto fica em duas
> metades: o **código AWS** (rede, EKS, IAM) é escrito, validado e testado offline, e o **cluster de verdade** é o
> `kind`, local e grátis. O README precisa dizer isso logo no topo, como o do foundation faz ("Nunca foi aplicado").

## 1. O que muda em relação ao roteiro original

| Peça do roteiro | Modo local | Status que vai para o README |
|---|---|---|
| Camadas `network` e `cluster` (EKS) | Escritas, `validate`, `terraform test` com `mock_provider`, `plan` offline com credenciais falsas se o módulo EKS permitir, grafo Mermaid | validado, **não aplicado** |
| Camada `bootstrap` (Argo CD por `helm_release`) | **Aplicada de verdade no kind**, com o provider Helm lendo o kubeconfig `kind-lab` | executado |
| Argo CD, app-of-apps, Kyverno, kube-prometheus-stack, NetworkPolicy, PDB, HPA, metrics-server | Idênticos, no kind | executado |
| AWS Load Balancer Controller + ALB | `ingress-nginx` no kind (substituto) | LBC: não executado |
| External Secrets + Secrets Manager | External Secrets com o provider **`fake`** (ou `kubernetes`) | provider AWS: não executado |
| Pod Identity e IAM | Roles, policies e associações escritas e checadas por testes e Rego | não aplicado |
| Teste de negação do Pod Identity | Equivalente local: `ClusterSecretStore` com `conditions.namespaces`; ExternalSecret de outro namespace é recusado | parcial |
| MongoDB Atlas | MongoDB como Deployment no próprio kind | n/a |
| Custo real, Cost Explorer, orçamento | Custo real **zero**; tabela de **estimativa** por hora com data e link do preço | estimado |
| Upgrade do Kubernetes executado | Runbook escrito, não executado | não executado |
| Cluster só em sessões curtas | Sem pressão de custo; `kind delete cluster` zera tudo | n/a |

O `foundation v1.2.0` (tags de sub-rede) continua útil: a camada `network` usa o módulo por tag, mesmo sem aplicar.

## 2. Pré-requisitos desta máquina (checados em 2026-10-29)

| Ferramenta | Estado |
|---|---|
| Terraform | 1.17.1 instalado |
| kubectl | 1.30.3 instalado (o kind vai subir uma versão mais nova; mantenha a distância de uma minor ou atualize) |
| Docker Desktop | **instalado, mas desligado** (a API não respondeu): abra o Docker Desktop antes de tudo |
| kind, helm, make, k6 | **não instalados** |

```powershell
choco install kind kubernetes-helm make k6 kubeconform -y
```

Dê pelo menos 6 a 8 GB de RAM ao Docker Desktop (Configurações, Resources): o kube-prometheus-stack e o Kyverno
pesam. Sem `make` o `Makefile` não roda; use o Git Bash ou o `choco` acima.

## 3. Ajustes nos projetos anteriores

### 3.1 foundation: concluído

`v1.2.0` com `public_subnet_tags` e `private_subnet_tags` (PR #1 mergeado).

### 3.2 orders-api: continuam necessários

1. **Métricas:** `io.micrometer:micrometer-registry-prometheus` no `pom.xml` e `include: health,prometheus` no
   `application-cloud.yml`. Sem isso, o `ServiceMonitor` da Etapa 5 não tem o que raspar.
2. **Probes:** o Spring liga `liveness` e `readiness` sozinho dentro do Kubernetes; confirme com `curl` no pod e, se
   preciso, force `management.endpoint.health.probes.enabled: true`.
3. **CI que abre PR no config** (Etapa 4): o `ci.yml` já publica `sha-<40 caracteres>`; falta o job novo. GitHub Actions
   é grátis em repositório público e não envolve a AWS.
4. **Imagem no kind:** duas rotas. Pacote GHCR público (o Argo puxa da internet) ou `docker build` local seguido de
   `kind load docker-image` (não depende de rede nem de visibilidade). Escolha e registre. A imagem é amd64.

O perfil `cloud` exige `MONGODB_URI` e não tem valor padrão: o pod só sobe se o Secret existir. Ótimo para a Etapa 3.

## 4. Decisões que o README precisa registrar

| Decisão | Recomendação | Por quê |
|---|---|---|
| Cluster local | kind com 1 control-plane e 2 workers | Dois workers permitem `drain`, PDB e `topologySpreadConstraints` de verdade |
| CNI | Calico (ou Cilium), com `disableDefaultCNI: true` | Garantir que a NetworkPolicy é aplicada; confirme com um pod de teste antes de confiar no resultado |
| Ingress | `ingress-nginx` | Substituto do ALB; registre que é uma troca de implementação, não equivalência |
| Segredos | External Secrets, provider `fake` | Mesmo fluxo ExternalSecret para Secret, sem Secrets Manager |
| Banco | `mongo:7` como Deployment | Substitui o Atlas |
| Ambientes no config | Um só (`workloads/pedidos/`) | Laboratório não justifica overlays; escreva o motivo |
| State do Terraform | Local (arquivo, fora do Git) | Sem bucket S3; o bloco `backend "s3"` das camadas AWS fica comentado, como no `bootstrap/` do foundation |

## 5. Etapa 0: estrutura e ferramentas (~1 h)

**Reaproveite do foundation:** `.gitignore`, `.pre-commit-config.yaml`, `.tflint.hcl` e o
padrão `docs/NN-*.md` com tabela de experimentos e coluna **Status**.

1. Nos dois repositórios: `LICENSE` (MIT) e `.gitignore` (Terraform; no config, nada de `*.env`).
2. Pastas, com `.gitkeep` onde ficarem vazias:

```powershell
cd D:\Projetos\Estudo\Terraform\eks-gitops-platform
mkdir terraform\network, terraform\cluster, terraform\bootstrap, kind, docs, policy, scripts
cd ..\eks-gitops-config
mkdir apps, workloads\pedidos
```

3. Instalar as ferramentas da seção 2, abrir o Docker Desktop e conferir `docker info`.
4. Anotar no README do platform a versão do Kubernetes do kind e a do EKS que o código AWS declara. Sem `aws`, a lista
   `aws eks describe-cluster-versions` não roda; use a página de versões do EKS e escreva a data da consulta.
5. Secret scanning e push protection nos dois repositórios, `pre-commit install`, `gitleaks`.
6. README de cada um, **com o aviso de "nunca aplicado na AWS" no topo**. Commit `chore: estrutura inicial`, tag `etapa-0`.

**Pronto quando:** `docker info` responde, as ferramentas têm versão, os dois repositórios têm a estrutura e o `pre-commit` passa.

## 6. Etapa 1: kind + Argo CD (6 a 9 h)

1. `kind/kind-config.yaml` com 1 control-plane, 2 workers, `disableDefaultCNI: true` e `extraPortMappings` (80 e 443)
   no control-plane com o rótulo `ingress-ready=true`. Instale o Calico e espere os nós `Ready`.
2. Argo CD numa versão fixa (confirme a do dia; só as 3 minors mais recentes recebem patch):

```bash
kind create cluster --name lab --config kind/kind-config.yaml
kubectl create namespace argocd
kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.6/manifests/install.yaml
```

3. `root.yaml` (app-of-apps) no config, com `automated: prune + selfHeal`. Não precisa mais do finalizer por causa de
   ALB, mas ele continua útil para o `delete` cascatear:

```yaml
metadata:
  name: root
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
```

4. `apps/pedidos.yaml` e `workloads/pedidos/` (Kustomize): MongoDB, Secret (por enquanto manual), `Deployment`, `Service`.
   O `Deployment` precisa de `securityContext` explícito, porque o Kyverno lê o pod e não o `USER` do Dockerfile:

```yaml
# esboço
spec:
  template:
    spec:
      securityContext: { runAsNonRoot: true, runAsUser: 10001, seccompProfile: { type: RuntimeDefault } }
      containers:
        - name: api
          image: ghcr.io/heldemfilipe/orders-api:sha-<40-caracteres>
          env: [{ name: SPRING_PROFILES_ACTIVE, value: cloud }]
          ports: [{ name: http, containerPort: 8080 }]
          resources: { requests: { cpu: 250m, memory: 384Mi }, limits: { memory: 640Mi } }
          securityContext: { allowPrivilegeEscalation: false, capabilities: { drop: [ALL] } }
          startupProbe:   { httpGet: { path: /actuator/health/liveness,  port: http }, periodSeconds: 5, failureThreshold: 30 }
          livenessProbe:  { httpGet: { path: /actuator/health/liveness,  port: http } }
          readinessProbe: { httpGet: { path: /actuator/health/readiness, port: http } }
```

5. Os três experimentos (self-heal, drift manual, rollback por `git revert`), anotando o **observado**.
6. CI do config: `kustomize build workloads/pedidos | kubeconform -strict` em PR.

Tag `etapa-1`. **Pronto quando:** os três experimentos funcionam e o README mostra o fluxo do commit ao sync.

## 7. Etapa 2: Terraform em camadas, validado offline (4 a 7 h)

1. **`terraform/network`:** módulo por tag, sem aplicar:

```hcl
module "network" {
  source = "git::https://github.com/heldemfilipe/terraform-aws-foundation.git//modules/network?ref=v1.2.0"

  nome               = "eks-lab"
  azs                = ["us-east-1a", "us-east-1b"]
  enable_nat_gateway = true   # NAT único; documente custo estimado e a alternativa

  public_subnet_tags  = { "kubernetes.io/role/elb" = "1" }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = "1" }
}
```

2. **`terraform/cluster`:** módulo `terraform-aws-modules/eks` com versão fixa (confira os nomes das variáveis da major
   escolhida): access entries, managed node group SPOT, add-ons `vpc-cni` (com NetworkPolicy ligada), `coredns`,
   `kube-proxy` e `eks-pod-identity-agent`. Leia a rede por `terraform_remote_state` com backend local.
3. **Provider da AWS em modo falso**, igual aos exemplos do foundation (`access_key = "mock"`, `skip_*`), para que
   nenhum comando fale com a AWS. Nunca rode `terraform apply` nestas duas camadas.
4. **Verificações** (cada uma vira uma linha na tabela de status):
   - `terraform fmt`, `validate`, `tflint` e Trivy, com `#trivy:ignore` justificado (endpoint público, por exemplo);
   - `terraform test` com `mock_provider "aws" {}` e `override_data` onde o módulo EKS consultar a AWS;
   - `terraform plan` offline: tente; o módulo EKS consulta dados da conta, então pode não ser possível. Se não der,
     registre "não executado" e o motivo, sem esconder;
   - `terraform graph -format=mermaid` das camadas no README;
   - políticas Rego com `conftest` sobre o plano ou sobre os testes: ao menos `tags obrigatórias` e `sem 0.0.0.0/0
     nas portas do cluster`.
5. **`terraform/bootstrap` (esta é de verdade):** `helm_release` do Argo CD apontando para o kubeconfig do kind
   (`config_path` e `config_context = "kind-lab"`). Em `terraform apply` aqui o que se cria é só no seu Docker.
   Na major 3 do provider Helm o bloco `kubernetes` virou atributo; confira a sintaxe da versão fixa.
6. **`Makefile` local** (receitas com tab):

```make
SHELL := bash

up:
	kind create cluster --name lab --config kind/kind-config.yaml
	./scripts/instala-cni.sh
	cd terraform/bootstrap && terraform init -input=false && terraform apply -auto-approve
	kubectl apply -f ../eks-gitops-config/root.yaml

down:
	kind delete cluster --name lab

verifica:
	kind get clusters
	docker ps --filter "name=lab" --format "{{.Names}}"

validate-aws:
	cd terraform/network && terraform init -backend=false -input=false && terraform validate
	cd terraform/cluster && terraform init -backend=false -input=false && terraform validate
```

   O `make up` completo (kind, Calico, Argo, root) é o equivalente local do "make up cria o cluster". Meça o tempo e
   registre; o equivalente do `make down` é `kind delete cluster`.

Tag `etapa-2`. **Pronto quando:** `make up` entrega o Argo CD sincronizando o `root`, `make validate-aws` passa e o README
tem a tabela de status das camadas.

## 8. Etapa 3: identidade e ingress (3 a 5 h)

1. **Parte AWS, só código:** em `terraform/cluster` (ou `iam`), as roles do LBC e do ESO com a trust policy do Pod Identity
   (`pods.eks.amazonaws.com`, ações `sts:AssumeRole` e `sts:TagSession`), a policy mínima do ESO restrita ao prefixo
   do segredo e as `aws_eks_pod_identity_association`. Proteja com um teste e uma política Rego que reprove `Action: "*"`
   ou `Resource: "*"` na role do ESO, no estilo do `trust.tftest.hcl` do foundation.
2. **Parte local, real:**
   - `ingress-nginx` como Application; `Ingress` do `pedidos` (host `pedidos.localhost`);
   - External Secrets como Application, com `ClusterSecretStore` no provider `fake` e um `ExternalSecret` que gera o
     `Secret` com `MONGODB_URI`; o `Deployment` usa `secretKeyRef`.
3. **Teste de negação local:** o `ClusterSecretStore` com `conditions: [{ namespaces: [pedidos] }]`; um
   `ExternalSecret` em outro namespace tentando o mesmo segredo deve ficar com erro de acesso. Guarde a saída. Marque
   como "parcial": o equivalente verdadeiro (pod sem identidade na AWS) não foi executado.

Tag `etapa-3`. **Pronto quando:** a API responde em `pedidos.localhost`, o segredo chega ao pod e a negação está documentada.

## 9. Etapa 4: entrega contínua (4 a 6 h)

1. Argo CD já vem do `bootstrap` (Etapa 2); o `root.yaml` entra no `make up`. Nada de `kubernetes_manifest` para isso.
2. No `orders-api`, job novo no `ci.yml` (só em `push` na `main`): `checkout` do config com um token de escopo mínimo
   (contents e pull requests só desse repositório, como secret `CONFIG_REPO_TOKEN`), `kustomize edit set image` com a tag
   `sha-${{ github.sha }}` e abrir o PR (`peter-evans/create-pull-request` ou `gh pr create`, actions fixadas por SHA).
3. Proteja a `main` do config exigindo PR e registre "um só ambiente".
4. Ponta a ponta: commit na API, imagem no GHCR, PR no config, merge, o Argo atualiza o kind. Meça cada trecho.
   Se o pacote GHCR for privado, torne-o público ou use `imagePullSecret`.

Tag `etapa-4`. **Pronto quando:** um commit na API chega ao kind só com o merge do PR.

## 10. Etapa 5: observabilidade (3 a 5 h)

1. Application `kube-prometheus-stack` com versão fixa, valores enxutos, sem PVC, `kubeEtcd`, `kubeScheduler` e
   `kubeControllerManager` desligados (no kind eles não expõem métricas do jeito padrão), `ServerSideApply=true`.
2. `Service` com porta nomeada `http` e `ServiceMonitor` com `release: kube-prometheus-stack`. Se o alvo não aparecer
   em `/targets`, a primeira suspeita é essa label.
3. Dashboard em `ConfigMap` (label `grafana_dashboard: "1"`) e `PrometheusRule` para pods reiniciando.
4. Teste do alerta: imagem que sai com erro (`CrashLoopBackOff`) dispara reinício; uma tag inexistente (`ImagePullBackOff`)
   **não** reinicia contêiner. Registre a diferença. Capture o Alertmanager e o dashboard em `docs/img/`.

Tag `etapa-5`.

## 11. Etapa 6: guardrails e falhas (4 a 7 h)

1. **Kyverno** (versão fixa), três políticas no namespace `pedidos`: requests e limits, sem tag `latest`, sem root.
   Primeiro `Audit`, depois `Enforce`. Confirme `ClusterPolicy` ou os tipos novos de política da versão instalada.
2. **NetworkPolicy** default-deny, liberando DNS, o `ingress-nginx` e o Prometheus; saída só para o Mongo. Confirme que o
   Calico aplica, com um pod de teste, antes de confiar no resultado.
3. `PodDisruptionBudget`, `HPA` com `metrics-server` como Application.
4. Experimentos, todos locais e reproduzíveis:

| Experimento | Cuidado |
|---|---|
| Política Kyverno | Pod sem limits no namespace `pedidos` deve ser negado; guarde a mensagem |
| `kubectl drain` num worker | Use `topologySpreadConstraints` para as réplicas não caírem no mesmo nó |
| k6 contra a API | A escala depende do seu hardware e do `requests.cpu`; registre a máquina usada |
| NetworkPolicy | Pod de outro namespace com `curl --max-time 5`, mais o contra-teste de um pod liberado |
| Mongo indisponível | O pod deve continuar `Ready` e `/pedidos` devolver erro |

Tag `etapa-6`.

## 12. Etapa 7: fechamento sem custo (2 a 3 h)

1. Tabela de **estimativa** de custo por hora do que o código AWS criaria (cluster, nós, NAT, ALB), com data da consulta e
   link da página de preço, dizendo explicitamente: "estimado, nada foi cobrado".
2. Custo real do projeto: US$ 0, e o motivo.
3. Runbook de atualização do Kubernetes (control plane, depois add-ons, depois nós), marcado **não executado**.
4. README final dos dois repositórios: problema, diagrama Mermaid (3 camadas e ciclo GitOps), decisões, tabela de status
   (executado, parcial, não executado), comparação com o Argo CD gerenciado e com o fluxo local, e os comandos de
   `make up`, `make down`, `make validate-aws`.
5. `gitleaks` limpo, tag `v1.0.0` e só então fixar `eks-gitops-platform` no perfil.

## 13. Resumo e ordem

| Etapa | Horas | AWS? | Resultado |
|---|---|---|---|
| 0 | ~1 | não | estrutura e ferramentas |
| 1 | 6 a 9 | não | Argo CD no kind e 3 experimentos |
| 2 | 4 a 7 | não, só código | camadas validadas e bootstrap no kind |
| 3 | 3 a 5 | não, só código | ingress, segredo e negação local |
| 4 | 4 a 6 | não | CI abre PR e o Argo atualiza o kind |
| 5 | 3 a 5 | não | dashboard e alerta |
| 6 | 4 a 7 | não | políticas e experimentos |
| 7 | 2 a 3 | não | estimativa, runbook e `v1.0.0` |

Total aproximado: **27 a 43 horas**, abaixo das 33 a 52 do roteiro original porque não há sessões de cluster na AWS.
Antes de tudo, o `orders-api` precisa dos ajustes 1 a 3 da seção 3.2.
