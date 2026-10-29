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
| Kubernetes no EKS (declarado no código) | _a definir na Etapa 2_ | Anotar a data da consulta da página de versões do EKS |
| Kubernetes no kind | _a definir na Etapa 1_ | |
| Argo CD | _a definir na Etapa 1_ | Só as 3 minors mais recentes recebem patch |
| Terraform | 1.16 ou mais novo | |

## Etapas

- [x] Etapa 0: repositórios, estrutura e ferramentas
- [ ] Etapa 1: kind e Argo CD
- [ ] Etapa 2: Terraform em camadas (validado offline)
- [ ] Etapa 3: identidade e ingress
- [ ] Etapa 4: entrega contínua
- [ ] Etapa 5: observabilidade
- [ ] Etapa 6: guardrails e experimentos de falha
- [ ] Etapa 7: fechamento e custo estimado

## Custo

Custo real: zero, porque nada é aplicado na AWS. A tabela de custo estimado por hora será publicada na Etapa 7.

## Licença

MIT. Veja [LICENSE](LICENSE).
