import http from "k6/http";
import { check } from "k6";

// Rampa gradual ate 50 VUs simultaneos, sustenta por 2 minutos, depois
// cai a zero - tempo suficiente pro HPA (fase 8.3) reagir e escalar
// replicas antes do fim do teste.
export const options = {
  stages: [
    { duration: "30s", target: 20 },
    { duration: "2m", target: 50 },
    { duration: "30s", target: 0 },
  ],
};

// DNS interno do cluster - o gateway tem Service type=LoadBalancer,
// mas isso tambem cria um ClusterIP normal, entao um pod dentro do
// cluster (como este Job) chega nele sem precisar do IP publico.
const GATEWAY_URL = __ENV.GATEWAY_URL || "http://gateway:8080";

export default function () {
  const res = http.post(
    `${GATEWAY_URL}/work`,
    JSON.stringify({ source: "k6-load-test" }),
    { headers: { "Content-Type": "application/json" } },
  );

  check(res, { "status is 202": (r) => r.status === 202 });
}
