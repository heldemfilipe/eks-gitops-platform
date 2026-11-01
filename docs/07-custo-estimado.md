# 07 - Custo (Etapa 7)

## Custo real: US$ 0

Nada deste projeto foi aplicado na AWS. As camadas `network` e `cluster` só foram escritas, validadas e testadas offline
(`terraform validate`, `terraform test` com `mock_provider`, `plan` da rede com provider falso e Rego). O cluster que
rodou de verdade é um `kind` dentro do Docker Desktop, na máquina local. Não há conta AWS configurada para este
projeto, nenhum recurso criado e nenhuma cobrança.

## Custo estimado: o que o código criaria

> **Estimado, nada foi cobrado.** Os números abaixo são uma conta de preços de lista para a região `us-east-1`, feita em
> **01/11/2026**, para o caso hipotético de alguém aplicar este código com os valores padrão. Não substitui a
> calculadora da AWS.

Premissas tiradas do código: 1 cluster EKS, 2 nós `t3.large` em capacidade `SPOT`, 1 NAT gateway (um só, não um por
zona), 2 zonas, e 1 ALB criado pelo AWS Load Balancer Controller a partir do Ingress.

| Item | Conta | Por hora | Por mês (730 h) | Fonte |
|---|---|---|---|---|
| Plano de controle do EKS (suporte padrão) | US$ 0,10 por cluster-hora | 0,100 | 73,00 | [AWS EKS pricing](https://aws.amazon.com/eks/pricing/) |
| NAT gateway | US$ 0,045 por hora, mais US$ 0,005 do IPv4 público | 0,050 | 36,50 | [AWS VPC pricing](https://aws.amazon.com/vpc/pricing/) (1) |
| ALB | US$ 0,0225 por hora, mais 2 IPv4 públicos (US$ 0,01) e 1 LCU (US$ 0,008) | 0,0405 | 29,57 | [AWS ELB pricing](https://aws.amazon.com/elasticloadbalancing/pricing/) |
| 2 nós `t3.large` em Spot | US$ 0,034 a 0,043 por nó-hora (varia) | 0,068 a 0,086 | 49,64 a 62,78 | agregador de terceiros (2) |
| **Total (nós em Spot)** | | **0,26 a 0,28** | **188,71 a 201,85** | |
| Total se os nós fossem sob demanda (US$ 0,0832 por nó-hora) | | 0,357 | 260,54 | agregador de terceiros (2) |

Sessão de estudo de 4 horas, depois apagando tudo: **cerca de US$ 1,03 a 1,43**.

Notas:

1. A página de preços da VPC só traz o exemplo do NAT gateway para US East (Ohio): US$ 0,045 por hora e por GB
   processado. Usei o mesmo valor para N. Virginia, que **não confirmei**. O processamento de dados (US$ 0,045 por GB)
   não está na tabela porque depende do tráfego.
2. A página de preços do EC2 não devolveu o valor da `t3.large`. O preço sob demanda (US$ 0,0832) e a faixa de Spot
   vêm de agregadores de terceiros ([Spendark](https://spendark.com/instances/t3-large/), [Holori](https://calculator.holori.com/aws/ec2/t3.large/us-east-1)),
   não da AWS. O preço Spot muda o tempo todo.

**Não incluído:** volumes EBS dos nós, tráfego de saída, logs do plano de controle no CloudWatch, Secrets Manager
(por segredo e por chamada) e impostos. Também não conferi se os nós `t3.large` comportam, na prática, Argo CD,
Prometheus, Kyverno e a API juntos: no `kind` a máquina local tem folga que a AWS não daria.

## A armadilha do suporte estendido

O plano de controle de uma versão do Kubernetes fora do suporte padrão passa a custar **US$ 0,60 por hora**, em vez de
US$ 0,10 ([AWS EKS pricing](https://aws.amazon.com/eks/pricing/)): sobram **US$ 365 por mês a mais** por cluster.
O EKS deixa o suporte estendido ligado por padrão. O código declara `kubernetes_version = "1.37"`, que em 01/11/2026 é a
versão mais nova do EKS, com suporte padrão até 01/12/2027 ([AWS: versões do Kubernetes](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html)).

## Como o custo seria contido, se algum dia fosse aplicado

- Apagar tudo ao fim da sessão (`terraform destroy` na ordem inversa das camadas), porque o plano de controle e o NAT
  cobram por hora mesmo sem uso.
- Alerta de orçamento antes do primeiro `apply` (o `orders-api` já traz um módulo `infra/orcamento` para isso).
- Manter a versão do Kubernetes em suporte padrão.
- Conferir os preços da calculadora da AWS no dia, não esta tabela.
