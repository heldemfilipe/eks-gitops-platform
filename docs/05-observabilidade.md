# 05 - Observabilidade (Etapa 5)

Métricas da API no Prometheus, dashboard no Grafana e alertas no Alertmanager, tudo no kind e entregue pelo Argo CD.

## O que foi montado

| Peça | Onde | Status |
|---|---|---|
| `kube-prometheus-stack` 92.17.0 (Prometheus, Alertmanager, Grafana, kube-state-metrics, operator) | `apps/kube-prometheus-stack.yaml` no config | executado no kind |
| `ServiceMonitor` `pedidos` (porta nomeada `http`, `/actuator/prometheus`) | `workloads/pedidos/servicemonitor.yaml` | executado |
| `PrometheusRule` `pedidos` (4 alertas) | `workloads/observabilidade/prometheusrule.yaml` | executado |
| Dashboard `Pedidos (orders-api)` em ConfigMap com a label `grafana_dashboard` | `workloads/observabilidade/dashboards/pedidos.json` | executado; carregado pelo Grafana (verificado pela API) |
| Imagem da API com `micrometer-registry-prometheus` | build local (`docker build` + `kind load docker-image`), tag `sha-915d408…` | executado |
| Capturas de tela do Alertmanager e do dashboard | `docs/img/` | **não feitas**; o resultado está em texto abaixo |

Ordem no Argo CD: `kube-prometheus-stack` na onda 0 (instala os CRDs), `observabilidade` na onda 1 (precisa dos CRDs
da `PrometheusRule`) e `pedidos` na onda 2 (traz o `ServiceMonitor`).

Acesso (port-forward, nada exposto): `make grafana-ui`, `make prometheus-ui`, `make alertmanager-ui`. A senha do Grafana
sai de `make grafana-senha`: **o chart gera uma senha aleatória**, não existe `prom-operator`.

## Decisões

| Decisão | Motivo |
|---|---|
| `kubeEtcd`, `kubeScheduler`, `kubeControllerManager`, `kubeProxy` desligados, com as regras deles | No kind eles não expõem métricas do jeito padrão: ligados, só gerariam alvos `down` e alertas que nunca fecham |
| `nodeExporter` desligado | Exige montar o `/` do nó como compartilhado, o que o Docker Desktop não permite |
| Sem PVC, retenção de 6 h | Laboratório; os dados somem se o pod do Prometheus reiniciar |
| `ServerSideApply=true` | Os CRDs do Prometheus Operator passam do limite de annotation do apply comum |
| `ServiceMonitor` com `release: kube-prometheus-stack` | O Prometheus só seleciona ServiceMonitors com essa label; sem ela o alvo nem aparece em `/targets` |
| Regra e dashboard numa Application própria (onda 1) | Dependem dos CRDs do operador; separa o que é do chart do que é nosso |
| Latência só como média e máximo, sem p95 | O Micrometer não publica histograma de buckets por padrão; p95 exigiria ligar `percentiles-histogram` na API |
| Imagem da API construída na máquina | Nada passa pelo GHCR nem pelo CI; o PR do config troca a tag e o `IfNotPresent` usa a imagem carregada no kind |

## Experimento: CrashLoopBackOff x ImagePullBackOff

Manifesto: [experimentos/falhas-observabilidade.yaml](experimentos/falhas-observabilidade.yaml). Dois pods no namespace
`pedidos`, aplicados e removidos à mão (fora do GitOps).

| Falha | Pod | Reinícios (`kube_pod_container_status_restarts_total`) | Alerta que disparou |
|---|---|---|---|
| Contêiner sai com `exit 1` | `exp-crash` | **4** em ~2 min | `PedidosContainerReiniciando` |
| Tag de imagem inexistente | `exp-pull` | **0** | `PedidosImagemNaoBaixa` |

- Os dois alertas apareceram no Alertmanager **126 s** depois de aplicar os pods (`for: 1m`, scrape de 15 s, avaliação e
  repasse ao Alertmanager). Este tempo é de uma medição só.
- `ImagePullBackOff` **não reinicia contêiner**: ele nunca chegou a rodar. Uma regra só sobre reinícios fica muda nesse
  caso, por isso existe `PedidosImagemNaoBaixa`, baseada em `kube_pod_container_status_waiting_reason`.
- Na direção oposta, não confie só no motivo de espera: `exp-crash` alternava entre `CrashLoopBackOff` e `Error`, e na
  consulta que fiz o motivo `CrashLoopBackOff` nem aparecia. O contador de reinícios é o sinal estável.

## Verificação da API

Depois do merge do PR #2 e do rollout (2 réplicas novas), com 30 chamadas a `/actuator/health` e 30 a uma rota inexistente:

| Consulta | Resultado |
|---|---|
| Alvos `pedidos` no Prometheus | 2, ambos `up` |
| `http_server_requests_seconds_count` por `status` | `200`: 63, `404`: 30 |
| `jvm_memory_used_bytes{area="heap"}` | 6 séries |
| Dashboard pela API do Grafana (`/api/search`) | encontrado (`uid pedidos-api`); a consulta `up` pelo datasource devolveu `200` |

## Problemas encontrados

| Problema | Causa | Solução |
|---|---|---|
| Grafana em `CrashLoopBackOff` | `OOMKilled` com limite de 256Mi | Limite 512Mi, request 256Mi |
| Argo CD não aplicava o novo limite | A sync anterior ficou esperando o Grafana saudável e bloqueou a seguinte | Terminei a operação presa (`status.operationState.phase: Terminating`); a sync nova aplicou os valores |
| Eu tinha dito que a senha do Grafana era `prom-operator` | Esta versão do chart gera a senha | `make grafana-senha`; corrigido aqui |

## Não executado

- Capturas de tela em `docs/img/`.
- Alertas por e-mail, Slack ou outro destino: o Alertmanager fica com o receptor padrão (`null`), só a tela mostra.
- Persistência de métricas.
