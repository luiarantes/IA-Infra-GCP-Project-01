.PHONY: help local-up local-up-simple local-up-distributed local-down local-status local-test local-agent local-smoke-test smoke-test local-load-test local-chaos-test local-traffic-start local-traffic-stop local-dashboards-reload obs-ui grafana-ui pyroscope-ui minio-ui chaos-ui k6-ui k6-report panel panel-sync local-aiops-ollama-up local-aiops-ollama-down local-aiops-chaos local-aiops-analyze local-aiops-fix local-aiops-verify local-aiops-demo gcp-up gcp-down aws-up aws-down

help:
	@echo "========================================================================="
	@echo "           AIOps Platform CLI — Multi-Target IaC & Observability         "
	@echo "========================================================================="
	@echo "  💻 Ambiente Local (Kind + Terraform + OpenObserve + Agentes):"
	@echo "    make panel               - Sincroniza links e abre o Painel de Controle AIOps no navegador"
	@echo "    make panel-sync          - Sincroniza links do ambiente ativo e exibe resumo"
	@echo "    make local-up            - Provisiona cluster local via Terraform e sobe os servicos (modo do tfvars)"
	@echo "    make local-up-simple     - Sobe ambiente local com Grafana Stack Simples (~8GB Docker)"
	@echo "    make local-up-distributed - Sobe ambiente local com Grafana Stack Distribuida + MinIO S3 (~12GB Docker)"
	@echo "    make local-dashboards-reload - Recarrega dashboards JSON no Grafana sem reiniciar cluster"
	@echo "    make local-down          - Destroi cluster local via Terraform (custo zero)"
	@echo "    make local-status        - Exibe status dos pods e consumo de CPU/Memoria"
	@echo "    make local-test          - Envia requisicoes de teste para os servicos"
	@echo "    make local-agent         - Executa container do Agente Self-Healing"
	@echo "    make smoke-test          - Executa Smoke Test rápido com k6 contra o gateway local"
	@echo "    make local-smoke-test    - Executa Smoke Test no cluster local Kind (Job Kubernetes)"
	@echo "    make local-load-test     - Executa teste de carga k6 pontual no cluster local"
	@echo "    make local-traffic-start - Inicia gerador de trafego continuo em background"
	@echo "    make local-traffic-stop  - Para gerador de trafego continuo"
	@echo "    make local-chaos-test    - Executa teste de caos (Chaos Toolkit)"
	@echo "    make obs-ui              - Abre a interface web do OpenObserve no navegador"
	@echo "    make grafana-ui          - Abre a interface web do Grafana OSS no navegador"
	@echo "    make pyroscope-ui        - Abre a interface web do Pyroscope no navegador"
	@echo "    make minio-ui            - Abre a interface web do MinIO Console no navegador"
	@echo "    make chaos-ui            - Abre a interface web do Chaos Mesh Dashboard no navegador"
	@echo "    make k6-ui               - Executa teste de carga k6 abrindo Web Dashboard ao vivo no navegador"
	@echo "    make k6-report           - Executa k6 e gera relatório gráfico HTML exportável (load-test/report.html)"
	@echo ""
	@echo "  🤖 Agentes AIOps & Self-Healing Local (Ollama + Telemetria):"
	@echo "    make local-aiops-ollama-up   - Sobe container Docker do Ollama com modelo qwen2.5-coder:7b"
	@echo "    make local-aiops-ollama-down - Para container Docker do Ollama"
	@echo "    make local-aiops-chaos SCENARIO=<probe-crash|oom-kill|restore> - Injeta anomalia controlada"
	@echo "    make local-aiops-analyze     - Executa Agente 1 (Pre-check deterministico + Diagnostico IA)"
	@echo "    make local-aiops-fix ISSUE=N - Executa Agente 2 (Inspeciona codigo e gera PR de fix)"
	@echo "    make local-aiops-verify ISSUE=N - Executa Agente 3 (Aplica deploy e valida resolucao)"
	@echo "    make local-aiops-demo        - Demonstra o ciclo completo de self-healing end-to-end"

	@echo ""
	@echo "  ☁️ Ambiente Nuvem GCP (GKE Standard Zonal SPOT + Pub/Sub):"
	@echo "    make gcp-up              - Dispara terraform-apply.yml no GitHub Actions"
	@echo "    make gcp-down            - Dispara terraform-destroy.yml no GitHub Actions"
	@echo ""
	@echo "  🟧 Ambiente Nuvem AWS (EKS SPOT + SQS - Scaffold Futuro):"
	@echo "    make aws-up              - [Scaffold] Provisionamento na AWS"
	@echo "    make aws-down            - [Scaffold] Destruicao na AWS"
	@echo "========================================================================="

local-up:
	@echo "🚀 Provisionando ambiente local (Kind) com Terraform..."
	@terraform -chdir=infra/environments/local init -upgrade
	@terraform -chdir=infra/environments/local apply -auto-approve
	@echo "✅ Ambiente local provisionado e operacional!"
	@terraform -chdir=infra/environments/local output
	@python3 scripts/sync_control_panel.py --env local

local-up-simple:
	@echo "🚀 Provisionando ambiente local (Kind) no modo Grafana Stack Simples..."
	@terraform -chdir=infra/environments/local init -upgrade
	@terraform -chdir=infra/environments/local apply -var="grafana_stack_mode=simple" -auto-approve
	@echo "✅ Ambiente local (Modo Simples) provisionado e operacional!"
	@terraform -chdir=infra/environments/local output
	@python3 scripts/sync_control_panel.py --env local

local-up-distributed:
	@echo "🚀 Provisionando ambiente local (Kind) no modo Grafana Stack Distribuída (MinIO S3)..."
	@terraform -chdir=infra/environments/local init -upgrade
	@terraform -chdir=infra/environments/local apply -var="grafana_stack_mode=distributed" -auto-approve
	@echo "✅ Ambiente local (Modo Distribuído) provisionado e operacional!"
	@terraform -chdir=infra/environments/local output
	@python3 scripts/sync_control_panel.py --env local


local-down:
	@echo "🛑 Destruindo ambiente local com Terraform..."
	@terraform -chdir=infra/environments/local destroy -auto-approve || ./local/scripts/local-env.sh down
	@echo "✅ Ambiente local destruído com sucesso. Custo zero!"

local-status:
	@chmod +x local/scripts/local-env.sh
	@./local/scripts/local-env.sh status

local-test:
	@chmod +x local/scripts/local-env.sh
	@./local/scripts/local-env.sh test

local-agent:
	@chmod +x local/scripts/local-env.sh
	@./local/scripts/local-env.sh agent

smoke-test:
	@echo "🚀 Executando Smoke Test local com k6 contra o gateway..."
	@k6 run -e GATEWAY_URL="http://localhost:8080" load-test/smoke-test.js

local-smoke-test:
	@echo "🚀 Criando ConfigMap do script de Smoke Test..."
	@kubectl create configmap k6-smoke-script -n apps --from-file=smoke-test.js=load-test/smoke-test.js --dry-run=client -o yaml | kubectl apply -f -
	@echo "🚀 Disparando Job de Smoke Test no cluster local..."
	@kubectl delete job k6-smoke-test -n apps 2>/dev/null || true
	@kubectl apply -f load-test/smoke-job.yaml
	@echo "⏳ Aguardando conclusão do Smoke Test..."
	@kubectl wait --for=condition=complete --timeout=60s job/k6-smoke-test -n apps || (kubectl logs job/k6-smoke-test -n apps && exit 1)
	@kubectl logs job/k6-smoke-test -n apps

local-load-test:
	@echo "🚀 Criando ConfigMap do script k6..."
	@kubectl create configmap k6-script -n apps --from-file=script.js=load-test/script.js --dry-run=client -o yaml | kubectl apply -f -
	@echo "🚀 Executando Job de Teste de Carga (k6) no cluster local..."
	@kubectl delete job k6-load-test -n apps 2>/dev/null || true
	@kubectl apply -f load-test/job.yaml
	@echo "⏳ Acompanhando execucao do teste de carga..."
	@kubectl wait --for=condition=complete --timeout=240s job/k6-load-test -n apps || true
	@kubectl logs -f job/k6-load-test -n apps

local-traffic-start:
	@echo "🚀 Iniciando gerador de tráfego contínuo no cluster local..."
	@kubectl create configmap traffic-generator-script -n observability --from-file=traffic-generator.js=local/scripts/traffic-generator.js --dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -f observability/traffic-generator.yaml
	@echo "✅ Gerador de tráfego contínuo ativo em background!"

local-traffic-stop:
	@echo "🛑 Parando gerador de tráfego contínuo..."
	@kubectl delete deployment traffic-generator -n observability 2>/dev/null || true
	@echo "✅ Gerador de tráfego contínuo finalizado."

local-chaos-test:
	@echo "🌪️ Executando Job de Chaos Engineering no cluster local..."
	@kubectl apply -f chaos-test/rbac.yaml
	@kubectl apply -f chaos-test/job.yaml
	@kubectl wait --for=condition=complete --timeout=120s job/chaos-test -n apps || true
	@kubectl logs job/chaos-test -n apps

obs-ui:
	@echo "📊 Abrindo OpenObserve em http://localhost:5080 ..."
	@open http://localhost:5080 2>/dev/null || echo "Acesse: http://localhost:5080 (Login: admin@example.com / ComplexPassword123#)"

grafana-ui:
	@echo "📈 Abrindo Grafana em http://localhost:3000 ..."
	@open http://localhost:3000 2>/dev/null || echo "Acesse: http://localhost:3000 (Login: admin / admin)"

pyroscope-ui:
	@echo "🔥 Abrindo Pyroscope em http://localhost:4040 ..."
	@open http://localhost:4040 2>/dev/null || echo "Acesse: http://localhost:4040"

minio-ui:
	@echo "🗄️ Abrindo MinIO Console em http://localhost:9001 ..."
	@open http://localhost:9001 2>/dev/null || echo "Acesse: http://localhost:9001 (Login: minioadmin / minioadmin)"

chaos-ui:
	@echo "🌪️ Abrindo Chaos Mesh Dashboard em http://localhost:2333 ..."
	@open http://localhost:2333 2>/dev/null || echo "Acesse: http://localhost:2333"

k6-ui:
	@echo "🚀 Iniciando teste de carga com k6 Web Dashboard ao vivo e exportação..."
	@echo "📊 O Dashboard ao vivo estará em: http://127.0.0.1:5665"
	@mkdir -p load-test/reports
	@TS=$$(date +'%Y%m%d_%H%M%S'); \
	REPORT="load-test/reports/k6-report-$$TS.html"; \
	K6_WEB_DASHBOARD=true K6_WEB_DASHBOARD_OPEN=true K6_WEB_DASHBOARD_EXPORT="$$REPORT" k6 run -e GATEWAY_URL="http://localhost:8080" load-test/script.js || true; \
	if [ -f "$$REPORT" ]; then \
		cp -f "$$REPORT" load-test/report.html 2>/dev/null || true; \
		echo "✅ Relatório salvo em: $$REPORT e load-test/report.html"; \
	fi
	@python3 scripts/sync_control_panel.py

k6-report:
	@echo "📊 Executando teste de carga e compilando relatório gráfico HTML..."
	@mkdir -p load-test/reports
	@TS=$$(date +'%Y%m%d_%H%M%S'); \
	REPORT="load-test/reports/k6-report-$$TS.html"; \
	k6 run -o web-dashboard=export="$$REPORT" -e GATEWAY_URL="http://localhost:8080" load-test/script.js || true; \
	if [ -f "$$REPORT" ]; then \
		cp -f "$$REPORT" load-test/report.html 2>/dev/null || true; \
		echo "✅ Relatório gerado com sucesso em: $$REPORT e load-test/report.html"; \
		open "$$REPORT" 2>/dev/null || open load-test/report.html 2>/dev/null || echo "Abra $$REPORT no navegador"; \
	fi
	@python3 scripts/sync_control_panel.py

panel:
	@python3 scripts/sync_control_panel.py --open

panel-sync:
	@python3 scripts/sync_control_panel.py --summary

local-dashboards-reload:
	@echo "🔄 Atualizando dashboards do Grafana a partir de observability/grafana-dashboards.yaml..."
	@kubectl apply -f observability/grafana-dashboards.yaml
	@kubectl rollout restart deployment/grafana -n observability
	@kubectl rollout status deployment/grafana -n observability --timeout=60s
	@echo "✅ Dashboards recarregados com sucesso no Grafana!"



local-aiops-ollama-up:
	@echo "🦙 Inicializando container do Ollama na porta 11434..."
	@docker run -d --name ollama -p 11434:11434 -v ollama_models:/root/.ollama --restart always ollama/ollama 2>/dev/null || docker start ollama
	@echo "⏳ Aguardando API do Ollama inicializar..."
	@for i in {1..30}; do curl -s http://localhost:11434/api/tags >/dev/null && break || sleep 1; done
	@echo "📦 Baixando modelo qwen2.5-coder:7b no Ollama..."
	@docker exec ollama ollama pull qwen2.5-coder:7b
	@echo "✅ Ollama operacional com qwen2.5-coder:7b pronto para inferência!"

local-aiops-ollama-down:
	@echo "🛑 Parando container do Ollama..."
	@docker stop ollama 2>/dev/null || true
	@docker rm ollama 2>/dev/null || true
	@echo "✅ Container do Ollama finalizado."

local-aiops-chaos:
	@chmod +x local/scenarios/inject-failure.sh
	@./local/scenarios/inject-failure.sh $(SCENARIO)

local-aiops-analyze:
	@chmod +x agents/log-analyzer/analyze-local.sh
	@./agents/log-analyzer/analyze-local.sh

local-aiops-fix:
	@chmod +x agents/pr-creator/create-pr-local.sh
	@./agents/pr-creator/create-pr-local.sh $(ISSUE)

local-aiops-verify:
	@chmod +x agents/verify-fix/verify-local.sh
	@./agents/verify-fix/verify-local.sh $(ISSUE)

local-aiops-demo:
	@echo "🚀 Iniciando Demonstração de Self-Healing Local (Closed Loop)..."
	@echo "1. Injetando falha de Liveness Probe..."
	@$(MAKE) local-aiops-chaos SCENARIO=probe-crash
	@echo "2. Acionando Agente 1 (Log & Metric Analyzer)..."
	@$(MAKE) local-aiops-analyze
	@echo "3. Acionando Agente 2 (PR & Fix Creator)..."
	@$(MAKE) local-aiops-fix
	@echo "4. Acionando Agente 3 (Verify Fix)..."
	@$(MAKE) local-aiops-verify
	@echo "🎉 Loop de Self-Healing concluído com sucesso!"

tshoot:
	@chmod +x scripts/tshoot.sh
	@./scripts/tshoot.sh $(CMD)

gcp-up:
	@echo "☁️ Disparando Terraform Apply no GCP via GitHub Actions..."
	gh workflow run terraform-apply.yml --ref main --repo luiarantes/IA-Infra-GCP-Project-01

gcp-down:
	@echo "🛑 Disparando Terraform Destroy no GCP via GitHub Actions..."
	gh workflow run terraform-destroy.yml --ref main --repo luiarantes/IA-Infra-GCP-Project-01 -f confirm="destroy"

aws-up:
	@echo "🟧 [Scaffold] O ambiente AWS EKS sera implementado na proxima fase."

aws-down:
	@echo "🟧 [Scaffold] O ambiente AWS EKS sera implementado na proxima fase."
