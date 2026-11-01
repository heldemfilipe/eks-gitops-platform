# 08 - Runbook: atualizar o Kubernetes do EKS

> **Status: não executado.** Nenhum cluster EKS existe neste projeto. Este roteiro foi escrito a partir da documentação
> da AWS e do código da camada `cluster`; os tempos não foram medidos e nenhum passo foi ensaiado. O `kind` local não
> ensaia upgrade: para trocar a versão, o cluster é recriado.

Regra de ouro: **uma versão menor de cada vez**, na ordem **plano de controle, add-ons, nós**. Pular versões não é
permitido, e deixar o plano de controle muito à frente dos nós esbarra na política de versões do Kubernetes.

## Antes

1. Confirmar a versão de destino e as datas na [página de versões do EKS](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html).
2. Procurar APIs removidas que o cluster ainda usa. As *upgrade insights* do EKS e a métrica
   `apiserver_requested_deprecated_apis` do plano de controle mostram quem chama o quê.
3. Conferir a compatibilidade dos componentes que esta plataforma instala: Argo CD, Traefik ou AWS Load Balancer
   Controller, External Secrets, kube-prometheus-stack, Kyverno e metrics-server. Cada um publica a matriz de versões do
   Kubernetes que suporta; se algum não suportar a versão nova, atualize-o **antes**, pelo Git.
4. Conferir as versões dos add-ons gerenciados (`vpc-cni`, `kube-proxy`, `coredns`, `eks-pod-identity-agent`) para a
   versão de destino: `aws eks describe-addon-versions --kubernetes-version <destino>`.
5. Estado saudável de partida: todas as Applications `Synced` e `Healthy`, nenhum alerta ativo, PDB do `pedidos` com
   disrupções permitidas maior que zero.

## Plano de controle

1. Abrir um PR que altera `kubernetes_version` em `terraform/cluster/variables.tf` (ou o valor passado na execução).
2. `terraform plan` na camada `cluster`: a única mudança esperada é a versão do cluster. Se aparecer recriação de
   recurso, parar.
3. `terraform apply` só depois da revisão. O tempo da troca não foi medido aqui; acompanhe o estado do cluster até
   `ACTIVE` antes de seguir.
4. Conferir que a API responde na versão nova e que as Applications continuam `Healthy`.

Reversão: um cluster atualizado por *in-place upgrade* pode voltar à versão menor anterior **em até 7 dias**, e só o
plano de controle ([AWS: rollback](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html)). Depois
disso, o caminho é seguir em frente ou restaurar a partir do Git em um cluster novo.

## Add-ons

Atualizar os add-ons gerenciados pelo módulo EKS, nesta ordem: `vpc-cni`, `kube-proxy`, `coredns`,
`eks-pod-identity-agent`. Manter `enableNetworkPolicy = "true"` na configuração do `vpc-cni`, senão a NetworkPolicy
deixa de ser aplicada sem aviso. Depois, os charts do GitOps que a matriz de compatibilidade exigir, cada um em um PR
no `eks-gitops-config`.

## Nós

1. O grupo de nós gerenciado atualiza em rolling: cria nós novos, esvazia (`drain`) e remove os antigos. Os nós **não**
   sobem sozinhos com o plano de controle.
2. O `PodDisruptionBudget` do `pedidos` (`minAvailable: 1`) e o `topologySpreadConstraints` existem para que isso não
   derrube a API. O experimento 3 da Etapa 6 mostrou o `drain` sem falhas no `kind`, mas com carga baixa.
3. Acompanhar `kubectl get nodes` e as Applications durante o processo; parar se algum pod ficar `Pending`.

## Depois

- Todas as Applications `Synced` e `Healthy`, nenhum alerta novo, k6 curto contra a API (como o experimento 4 da Etapa 6)
  e a lista de nós na versão nova.
- Registrar a data e a versão. Repetir a conta do [custo](07-custo-estimado.md) se a versão anterior tiver passado para
  o suporte estendido.

## O que este runbook não cobre

- Upgrade de duas versões ou mais de uma vez (a regra é uma por vez).
- Nós autogerenciados, Fargate e Karpenter: não são usados aqui.
- Janela de manutenção e comunicação com usuários.
