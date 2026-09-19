import http from "k6/http";
import { check, sleep } from "k6";

// Smoke test: validação rápida pós-deploy (5 segundos / 5 iterações)
// Garante que o gateway, DNS e a cadeia completa de microsserviços respondem
export const options = {
  vus: 1,
  iterations: 5,
  thresholds: {
    // 0% de falha tolerado no smoke test pós-deploy
    http_req_failed: ["rate==0"],
    // 99% das requisições devem responder em menos de 1.5s
    http_req_duration: ["p(99)<1500"],
  },
};

const GATEWAY_URL = __ENV.GATEWAY_URL || "http://gateway.apps:8080";

export default function () {
  // 1. Healthcheck do Gateway
  const healthRes = http.get(`${GATEWAY_URL}/healthz`);
  check(healthRes, {
    "gateway healthz status is 200": (r) => r.status === 200,
  });

  // 2. Fluxo assíncrono E2E (Gateway -> API -> Pub/Sub -> Worker -> Downstream)
  const workRes = http.post(
    `${GATEWAY_URL}/work`,
    JSON.stringify({ source: "smoke-test" }),
    { headers: { "Content-Type": "application/json" } },
  );
  check(workRes, {
    "gateway work status is 202": (r) => r.status === 202,
  });

  sleep(0.5);
}
