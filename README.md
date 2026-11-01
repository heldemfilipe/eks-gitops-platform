# eks-gitops-platform

Plataforma Kubernetes na AWS criada em camadas com Terraform e operada por GitOps (Argo CD), com observabilidade
e guardrails. Os manifestos que o Argo CD lê ficam em [`eks-gitops-config`](https://github.com/heldemfilipe/eks-gitops-config).

> **Status:** projeto de estudo, em construção. **Nada é aplicado na AWS.** O código das camadas AWS (rede, EKS, IAM)
> é validado e testado offline; o cluster de verdade é um `kind` local. O que não foi executado de fato está marcado
> como tal na tabela de status.

## Problema

Um cluster que sobe e roda um Hello World não mostra nada. O que vale mostrar são as decisões, o que acontece
quando algo falha e como se opera: criar em camadas, entregar por Git, observar, barrar o que é inseguro.

## Como está dividido

| Pasta | O que tem |
|---|---|
| `terraform/network` | Rede, usando o módulo `network` do [terraform-aws-foundation](https://github.com/heldemfilipe/terraform-aws-foundation) por tag. Só código, não aplicado |
| `terraform/cluster` | EKS e identidades (Pod Identity). Só código, não aplicado |
| `terraform/bootstrap` | Argo CD por `helm_release`. Aplicado no `kind` local |
| `kind/` | Configuração do cluster local |
| `policy/` | Políticas em Rego (conftest) para o código Terraform |
| `scripts/` | Auxiliares do `Makefile` |
| `docs/` | Roteiro e guias; comece por [docs/00-roteiro-passo-a-passo.md](docs/00-roteiro-passo-a-passo.md) |

## Versões

| Peça | Versão | Observação |
|---|---|---|
| Kubernetes no EKS (declarado no código) | 1.37 | Valor do roteiro (consultado em 21/10/2026); **a confirmar** na página de versões do EKS antes de qualquer uso real |
| Módulo EKS | terraform-aws-modules/eks 21.29.0 | Versão fixa |
| Chart do Argo CD | argo-cd 10.11.6 | Instala o Argo CD v3.5.6 |
| Kubernetes no kind | v1.37.0 | Imagem padrão do kind v0.33.0 |
| Argo CD | v3.5.6 | Só as 3 minors mais recentes recebem patch |
| Terraform | 1.16 ou mais novo | |

## Etapas

- [x] Etapa 0: repositórios, estrutura e ferramentas
- [x] Etapa 1: kind e Argo CD (veja [docs/01-kind-argocd.md](docs/01-kind-argocd.md))
- [x] Etapa 2: Terraform em camadas (rede e cluster validados offline; bootstrap aplicado no kind; veja [docs/02-terraform-camadas.md](docs/02-terraform-camadas.md))
- [x] Etapa 3: identidade e ingress (Pod Identity só em código; Traefik e External Secrets reais no kind; veja [docs/03-identidade-ingress.md](docs/03-identidade-ingress.md))
- [x] Etapa 4: entrega contínua (script que abre o PR no config e sync do Argo medido; job do Actions não executado, por decisão; veja [docs/04-entrega-continua.md](docs/04-entrega-continua.md))
- [x] Etapa 5: observabilidade (kube-prometheus-stack, ServiceMonitor, dashboard e alertas no kind; veja [docs/05-observabilidade.md](docs/05-observabilidade.md))
- [ ] Etapa 6: guardrails e experimentos de falha
- [ ] Etapa 7: fechamento e custo estimado

## Como rodar

Requisitos: Docker Desktop ligado, `kind`, `kubectl`, `helm` e `make`.

```bash
make up            # kind, Calico, Argo CD (Terraform, camada bootstrap) e o root.yaml; ~167 s
make down          # apaga o cluster; ~4 s
make validate-aws  # fmt, validate e terraform test nas camadas network e cluster (nunca há apply)
make policy        # opa test e conftest sobre o plano real da rede
make scan          # Trivy no código próprio
```

## Status das camadas

| Camada | Status |
|---|---|
| `terraform/network` | validado, 16 recursos no plan offline, **não aplicado** |
| `terraform/cluster` | validado e testado com mock; `plan` offline não executado (o módulo EKS consulta o STS); **não aplicado** |
| `terraform/bootstrap` | **aplicado no kind** (Argo CD v3.5.6) |

## Experimentos

| Experimento | Status | Resultado observado |
|---|---|---|
| Self-heal | executado | O Argo CD recriou o Deployment apagado; 2 réplicas `Ready` em cerca de 21 s |
| Drift manual | executado | `scale --replicas=5` voltou a 2 em cerca de 4 s |
| Rollback | executado | Tag quebrada: pod novo em `ImagePullBackOff` e os antigos seguiram `Running`; `git revert` voltou a `Synced/Healthy` em cerca de 7 s |
| Segredo entregue pelo External Secrets | executado (provider `fake`) | `Secret pedidos-mongodb` criado no namespace da API; `MONGODB_URI` no pod vem dele |
| Ingress | executado (Traefik, não ALB) | `Host: pedidos.localhost` devolve `200`; sem o `Host`, `404` |
| Negação de segredo | parcial | `ExternalSecret` em outro namespace recusado (`denied by spec.condition`) e Secret não criado. Pod sem Pod Identity recebendo `AccessDenied` da AWS: **não executado** |
| Pod Identity (LBC e ESO) | não aplicado | Roles, policies e associações validadas por `terraform test` (com mutação) e Rego |

## Custo

Custo real: zero, porque nada é aplicado na AWS. A tabela de custo estimado por hora será publicada na Etapa 7.

## Licença

MIT. Veja [LICENSE](LICENSE).
