// Experimento da Etapa 6: carga na API pelo Traefik do kind. Rode com:
//   docker run --rm -v "<pasta>:/scripts" grafana/k6 run /scripts/k6-pedidos.js
// Dentro do contêiner, o host é host.docker.internal; o roteamento do Traefik usa o cabeçalho Host.
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 60 },
    { duration: '90s', target: 60 },
    { duration: '20s', target: 0 },
  ],
  thresholds: { http_req_failed: ['rate<0.05'] },
};

const base = 'http://host.docker.internal';
const params = { headers: { Host: 'pedidos.localhost', 'Content-Type': 'application/json' } };
const pedido = JSON.stringify({ clienteId: 'k6', itens: [{ produto: 'caneta', quantidade: 2, precoUnitario: 3.5 }] });

export default function () {
  const criado = http.post(`${base}/pedidos`, pedido, params);
  check(criado, { 'POST /pedidos 201': (r) => r.status === 201 });
  // Lê o pedido criado (GET /pedidos devolveria a coleção inteira, que só cresce durante o teste).
  const lido = http.get(`${base}/pedidos/${criado.json('id')}`, params);
  check(lido, { 'GET /pedidos/{id} 200': (r) => r.status === 200 });
  sleep(0.1);
}
