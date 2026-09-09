# Stack de Observabilidade Agnóstica (OpenTelemetry + OpenObserve)

A plataforma utiliza uma stack de observabilidade **100% agnóstica de fornecedor de nuvem (zero vendor lock-in)** baseada no padrão CNCF **OpenTelemetry (OTel)** e no motor colunar de alta performance **OpenObserve**.

---

## 🏗️ Arquitetura da Pipeline de Telemetria

```
  [ Microsserviços / Aplicações ]
    - gateway
    - service-api               (OTLP HTTP / 4318)
    - service-worker       ---------------------------->  [ OpenTelemetry Collector ]
    - service-downstream                                  (Two-Tier Gateway Pod)
    - BuscaCEP                                                      │
                                                              (OTLP Exporter)
                                                                    ▼
                                                          [ OpenObserve Engine ]
                                                          (Apache DataFusion + Parquet)
                                                                    │
                                                          (Web UI / Porta 5080)
                                                                    ▼
                                                      [ Engenharia / SRE / Agentes AIOps ]
```

---

## 🔑 Pilares Principais

1. **Agnosticismo Total**:
   - Os microsserviços emitem exclusivamente no protocolo OTLP (`OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318/v1/traces`).
   - Nenhuma biblioteca ou SDK proprietário de nuvem (Google Cloud Trace/Logging/Monitoring ou AWS CloudWatch) é embarcado na aplicação.
2. **Armazenamento Colunar em Apache Parquet**:
   - O OpenObserve grava logs, métricas e traces em arquivos `.parquet` compactados com Zstandard (ZSTD), garantindo compressão de até 90% e consultas SQL ultra-rápidas via Apache DataFusion.
3. **Correlação Nativa de Logs e Traces**:
   - Os logs estruturados contêm automaticamente `trace_id` e `span_id`. Na UI do OpenObserve, ao clicar em uma linha de log, é possível navegar diretamente para o waterfall do trace correspondente.
4. **Filtro Automático de Probes**:
   - O processador `filter/healthchecks` do OTel Collector descarta requisições aos endpoints `/healthz` e `/readyz`, eliminando ruído desnecessário.

---

## 📊 Manifestos Versionados

* [`observability/openobserve.yaml`](openobserve.yaml): Deployment com PersistentVolumeClaim e Service (`LoadBalancer` para Nuvem e `NodePort` para Kind).
* [`observability/otel-collector.yaml`](otel-collector.yaml): ConfigMap, Deployment, Service e RBAC do OpenTelemetry Collector Contrib v0.108.0.
* [`observability/traffic-generator.yaml`](traffic-generator.yaml): Deployment k6 leve gerando carga sintética contínua (~2 req/s) para manter gráficos e traces populados.
* [`observability/podmonitoring.yaml`](podmonitoring.yaml): Manifesto histórico para compatibilidade legada.

---

## 🚀 Como Acessar a Interface do OpenObserve

* **Ambiente Local**:
  - URL: `http://localhost:5080` (ou via comando `make obs-ui`)
  - Login: `admin@example.com` / `ComplexPassword123#`
* **Ambiente GCP GKE**:
  - O OpenObserve é provisionado como `type: LoadBalancer` e recebe um IP público direto na porta `5080` (exibido ao final do workflow `deploy-observability.yml`).

---

## 🔍 Consultas SQL de Exemplo no OpenObserve

No painel de SQL do OpenObserve, execute consultas diretamente sobre os streams:

```sql
-- Contagem de requisições por código de status HTTP
SELECT "http.status_code", count(*) as total
FROM default
WHERE "http.status_code" IS NOT NULL
GROUP BY "http.status_code"
ORDER BY total DESC;

-- Buscar traces com latência superior a 500ms
SELECT trace_id, duration_ms, service_name, name
FROM traces
WHERE duration_ms > 500
ORDER BY duration_ms DESC
LIMIT 20;
```
