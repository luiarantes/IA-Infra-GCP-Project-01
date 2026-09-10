.PHONY: help local-up local-down local-status local-test local-agent local-load-test local-chaos-test local-traffic-start local-traffic-stop obs-ui gcp-up gcp-down aws-up aws-down

help:
	@echo "========================================================================="
	@echo "           AIOps Platform CLI — Multi-Target IaC & Observability         "
	@echo "========================================================================="
	@echo "  💻 Ambiente Local (Kind + Terraform + OpenObserve + Agentes):"
	@echo "    make local-up            - Provisiona cluster local via Terraform e sobe os servicos"
	@echo "    make local-down          - Destroi cluster local via Terraform (custo zero)"
	@echo "    make local-status        - Exibe status dos pods e consumo de CPU/Memoria"
	@echo "    make local-test          - Envia requisicoes de teste para os servicos"
	@echo "    make local-agent         - Executa container do Agente Self-Healing"
	@echo "    make local-load-test     - Executa teste de carga k6 pontual no cluster local"
	@echo "    make local-traffic-start - Inicia gerador de trafego continuo em background"
	@echo "    make local-traffic-stop  - Para gerador de trafego continuo"
	@echo "    make local-chaos-test    - Executa teste de caos (Chaos Toolkit)"
	@echo "    make obs-ui              - Abre a interface web do OpenObserve no navegador"
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

local-load-test:
	@echo "🚀 Criando ConfigMap do script k6..."
	@kubectl create configmap k6-script --from-file=script.js=load-test/script.js --dry-run=client -o yaml | kubectl apply -f -
	@echo "🚀 Executando Job de Teste de Carga (k6) no cluster local..."
	@kubectl delete job k6-load-test 2>/dev/null || true
	@kubectl apply -f load-test/job.yaml
	@echo "⏳ Acompanhando execucao do teste de carga..."
	@kubectl wait --for=condition=complete --timeout=240s job/k6-load-test || true
	@kubectl logs -f job/k6-load-test

local-traffic-start:
	@echo "🚀 Iniciando gerador de tráfego contínuo no cluster local..."
	@kubectl create configmap traffic-generator-script --from-file=traffic-generator.js=local/scripts/traffic-generator.js --dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -f observability/traffic-generator.yaml
	@echo "✅ Gerador de tráfego contínuo ativo em background!"

local-traffic-stop:
	@echo "🛑 Parando gerador de tráfego contínuo..."
	@kubectl delete deployment traffic-generator 2>/dev/null || true
	@echo "✅ Gerador de tráfego contínuo finalizado."

local-chaos-test:
	@echo "🌪️ Executando Job de Chaos Engineering no cluster local..."
	@kubectl apply -f chaos-test/job.yaml
	@kubectl wait --for=condition=complete --timeout=120s job/chaos-test || true
	@kubectl logs job/chaos-test

obs-ui:
	@echo "📊 Abrindo OpenObserve em http://localhost:5080 ..."
	@open http://localhost:5080 2>/dev/null || echo "Acesse: http://localhost:5080 (Login: admin@example.com / ComplexPassword123#)"

grafana-ui:
	@echo "📈 Abrindo Grafana em http://localhost:3000 ..."
	@open http://localhost:3000 2>/dev/null || echo "Acesse: http://localhost:3000 (Login: admin / admin)"

pyroscope-ui:
	@echo "🔥 Abrindo Pyroscope em http://localhost:4040 ..."
	@open http://localhost:4040 2>/dev/null || echo "Acesse: http://localhost:4040"

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
