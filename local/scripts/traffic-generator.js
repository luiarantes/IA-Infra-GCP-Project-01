import http from "k6/http";
import { check, sleep } from "k6";

export const options = {
  vus: 2,
  duration: "4h", // Gera tráfego contínuo e suave por até 4 horas
};

const GATEWAY_URL = __ENV.GATEWAY_URL || "http://gateway:8080";
const BUSCACEP_URL = __ENV.BUSCACEP_URL || "http://buscacep-api:8000";

const CEPS = ["01310-100", "01001-000", "20040-002", "70040-010", "30130-000"];

export default function () {
  // 1. Chamada suave para o Gateway dos microsserviços
  const resGateway = http.post(
    `${GATEWAY_URL}/work`,
    JSON.stringify({ origem: "continuous-traffic", status: "ok" }),
    { headers: { "Content-Type": "application/json" } }
  );
  check(resGateway, { "gateway 202": (r) => r.status === 202 });

  // 2. Chamada suave para a API BuscaCEP
  const cep = CEPS[Math.floor(Math.random() * CEPS.length)];
  const resBusca = http.get(`${BUSCACEP_URL}/api/cep/${cep}`);
  check(resBusca, { "buscacep 200": (r) => r.status === 200 });

  // Pausa suave de 1s para manter tráfego constante e sem sobrecarga
  sleep(1);
}
