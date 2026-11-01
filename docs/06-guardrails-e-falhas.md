# 06 - Guardrails e falhas (Etapa 6)

Políticas que barram pods ruins, rede fechada por padrão, disponibilidade sob drenagem e carga, e o que acontece quando
o banco some. Tudo no kind; nada na AWS.

## O que foi montado

| Peça | Onde (repositório `eks-gitops-config`) | Status |
|---|---|---|
| Kyverno 1.19.2 (chart 3.9.2), uma réplica por controlador | `apps/kyverno.yaml` | executado no kind |
| 3 `NamespacedValidatingPolicy` no namespace `pedidos` | `workloads/politicas/` | executado |
| `NetworkPolicy`: default-deny, DNS, entrada, saída da API e entrada do Mongo | `workloads/pedidos/networkpolicy.yaml` | executado |
| `PodDisruptionBudget` (`minAvailable: 1`) | `workloads/pedidos/pdb.yaml` | executado |
| `HorizontalPodAutoscaler` (2 a 4 réplicas, 70% de CPU) | `workloads/pedidos/hpa.yaml` | executado |
| `metrics-server` 3.14.0 com `--kubelet-insecure-tls` | `apps/metrics-server.yaml` | executado |
| `topologySpreadConstraints` por nó (`ScheduleAnyway`) | `workloads/pedidos/deployment.yaml` | executado |

## Decisões

| Decisão | Motivo |
|---|---|
| `NamespacedValidatingPolicy` (`policies.kyverno.io/v1`, regras em CEL) em vez de `ClusterPolicy` | No Kyverno 1.19 o `ClusterPolicy` está marcado como obsoleto no próprio CRD; o tipo novo já nasce limitado a um namespace |
| Políticas testadas em `Audit` primeiro, `Deny` só no Git | O `Audit` mostrou que `pedidos` e `mongo` já passavam 3/3 antes de bloquear qualquer coisa |
| Exigir `requests.cpu`, `requests.memory` e `limits.memory`, **sem** limite de CPU | Limite de CPU só causa throttling; o HPA calcula a utilização sobre o request de CPU |
| "Sem root" lê `runAsNonRoot` no manifesto | O Kyverno não enxerga o `USER` do Dockerfile |
| Sem `replicas` no Deployment | O HPA é dono do número de réplicas; senão o Argo CD brigaria com ele |
| `ScheduleAnyway` no spread por nó | Com `DoNotSchedule`, um nó drenado deixaria as réplicas em `Pending` (o nó cordonado ainda conta como domínio vazio) |
| `--kubelet-insecure-tls` no metrics-server | O kubelet do kind tem certificado que o metrics-server não valida. Só laboratório |
| Application `kyverno` com `ServerSideDiff=true` | Com `ServerSideApply`, os CRDs ficavam `OutOfSync` para sempre |

## Experimentos

Máquina: Windows 11, 12 CPUs lógicas, 16 GB de memória para o Docker Desktop; cluster `kind` com 1 control-plane e
2 workers. Os números dependem dela e vêm de uma medição só.

### 1. Política do Kyverno

Manifesto: [experimentos/kyverno-pod-sem-limits.yaml](experimentos/kyverno-pod-sem-limits.yaml).

| Modo | Pod `nginx:latest`, sem limits, root | Pods reais (`pedidos`, `mongo`) |
|---|---|---|
| `Audit` | criado; relatório com 0 passes e 3 falhas | 3 passes e 0 falhas |
| `Deny` | negado | sem mudança |

Mensagem guardada (`Deny`):

```text
Error from server: admission webhook "nvpol.validate.kyverno.svc-fail" denied the request:
Policy exige-requests-e-limits failed: Todo contêiner precisa de requests.cpu, requests.memory e limits.memory.;
Policy proibe-tag-latest failed: A imagem precisa ter uma tag explícita que não seja 'latest' (ou um digest).;
Policy proibe-root failed: O pod ou todos os contêineres precisam de securityContext.runAsNonRoot: true.
```

Um pod só sem limits foi negado só pela primeira política; um pod conforme (`busybox:1.37`, non-root, com requests e
limits) foi criado.

### 2. NetworkPolicy (Calico)

Antes de confiar no resultado, o teste com um pod `curlimages/curl` em outro namespace:

| Teste (de um pod em outro namespace) | Sem NetworkPolicy | Com NetworkPolicy |
|---|---|---|
| `curl` na API, `--max-time 5` | `200` em 0,02 s | **timeout** (código 28) |
| `nc -z -w 5` no Mongo | conecta | **bloqueado** |
| API (dentro do pod) para o Grafana de outro namespace | não medido | **bloqueado** |

Contra-testes (o que deve continuar funcionando): pelo Traefik, `/actuator/health` deu `200`; `GET /pedidos` (usa o
Mongo) deu `200`; os 2 alvos do Prometheus continuaram `up`; `wget` em `localhost:8080` dentro do pod respondeu `UP`.
O último mostra que o `wget` existe na imagem, então o bloqueio da saída não é um falso positivo por falta da ferramenta.

### 3. `kubectl drain` com PDB e spread

Cenário: 2 réplicas, uma em cada worker; carga contínua de cerca de 2 requisições por segundo no Traefik durante a
drenagem de `lab-worker2`.

| Medida | Resultado |
|---|---|
| Requisições durante ~99 s | 186, **todas `200`** |
| Drenagem terminou em | 2 s |
| 2 réplicas `Ready` de novo | 12 s depois de iniciar o drain |
| Depois | as duas réplicas ficaram no `lab-worker`; o `ScheduleAnyway` não reequilibra sozinho |

- O primeiro drain falhou: um pod meu sem controlador (`outro/cliente`) exige `--force`. Removi o pod e repeti.
- A carga dessa medição é baixa; prova que não houve falha nesse cenário, não que a API suporta picos durante uma
  drenagem.

### 4. k6 e HPA

Script: [experimentos/k6-pedidos.js](experimentos/k6-pedidos.js) (60 usuários virtuais por 90 s, POST e GET de um pedido).

| Medida | Resultado |
|---|---|
| Requisições | 115.174 (822/s) |
| Latência | média 9,5 ms, p95 29,9 ms, máxima 801 ms |
| Falhas | **11 de 57.587 `POST`** (0,02%); não investiguei a causa |
| HPA | 2 → 4 réplicas (o máximo) 37 s depois de iniciar o k6, com a CPU em 182% do request |
| Scale-down | 3 réplicas ~63 s e 2 réplicas ~78 s depois do fim da carga (estabilização de 60 s) |

O Mongo do laboratório não tem volume e guardou ~57 mil pedidos de teste na memória do pod.

### 5. Mongo indisponível

Para o Argo CD não reverter o `scale`, pausei o auto-sync de `root` e `pedidos` durante o teste e o religuei depois.

| Medida (Mongo com 0 réplicas) | Resultado |
|---|---|
| Pods da API | continuam `Ready`, sem reinício |
| `/actuator/health/readiness` e `/liveness` | `200` |
| `GET /pedidos` | **`500` depois de 30 s** |
| `/actuator/health` (geral, inclui o Mongo) | sem resposta em 5 s |
| Recuperação ao subir o Mongo | `GET /pedidos` voltou a `200` em 23 s, sem reiniciar a API |

O pod fica `Ready` com o banco fora do ar (como o roteiro prevê), mas cada requisição trava 30 s antes de falhar: é o
tempo padrão de seleção de servidor do driver. Num cenário real isso esgotaria as threads. Reduzir esse tempo não foi feito.

## Problemas encontrados

| Problema | Causa | Solução |
|---|---|---|
| App `kyverno` `OutOfSync` para sempre | Diff comum contra CRDs aplicados com `ServerSideApply` | `argocd.argoproj.io/compare-options: ServerSideDiff=true` |
| `kubectl drain` falhou | Pod de teste sem controlador | Removi o pod |
| Medição de disponibilidade cobriu só 14 s | O loop em segundo plano morreu com a chamada que o iniciou | Repeti tudo numa chamada só |
| `kubectl scale` do Mongo seria desfeito | `selfHeal` do Argo CD | Pausei o auto-sync de `root` e `pedidos` e religuei depois |
| HPA com `FailedGetResourceMetric` | O `metrics-server` ainda subia (ou foi drenado) | Some sozinho em segundos; só ruído nos eventos |

## Não executado

- Reduzir o timeout do driver do Mongo na API.
- Investigar as 11 falhas de `POST` sob carga.
- Experimento com o Kyverno fora do ar (o webhook de política está em `Fail`).
