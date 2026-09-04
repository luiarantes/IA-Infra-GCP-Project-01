.PHONY: help local-up local-down local-status local-test local-agent local-load-test local-chaos-test gcp-up gcp-down

help:
	@echo "========================================================================="
	@echo "                    AIOps GCP / Local Platform CLI                      "
	@echo "========================================================================="
	@echo "  Ambiente Local (Kind + OpenObserve + Agentes):"
	@echo "    make local-up          - Cria cluster Kind e sobe todos os servicos"
	@echo "    make local-down        - Destroi cluster Kind local (custo zero)"
	@echo "    make local-status      - Exibe status dos pods e consumo de CPU/Memoria"
	@echo "    make local-test        - Envia requisicoes de teste para os servicos"
	@echo "    make local-agent       - Roda container do Agente Self-Healing"
	@echo "    make local-load-test   - Executa teste de carga k6 no cluster local"
	@echo "    make local-chaos-test  - Executa teste de caos no cluster local"
	@echo ""
	@echo "  Ambiente Nuvem (Google Cloud Platform):"
	@echo "    make gcp-up            - Dispara terraform-apply.yml no GitHub Actions"
	@echo "    make gcp-down          - Dispara terraform-destroy.yml no GitHub Actions"
	@echo "========================================================================="

local-up:
	@chmod +x local/scripts/local-env.sh
	@./local/scripts/local-env.sh up

local-down:
	@chmod +x local/scripts/local-env.sh
	@./local/scripts/local-env.sh down

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
	@kubectl apply -f local/manifests/traffic-generator.yaml
	@echo "✅ Gerador de tráfego contínuo ativo em background no Kind!"

local-traffic-stop:
	@echo "🛑 Parando gerador de tráfego contínuo..."
	@kubectl delete deployment traffic-generator 2>/dev/null || true
	@echo "✅ Gerador de tráfego contínuo finalizado."

local-chaos-test:
	@echo "🌪️ Executando Job de Chaos Engineering no cluster local..."
	@kubectl apply -f chaos-test/job.yaml
	@kubectl wait --for=condition=complete --timeout=120s job/chaos-test || true
	@kubectl logs job/chaos-test

gcp-up:
	@echo "☁️ Disparando Terraform Apply no GCP via GitHub Actions..."
	gh workflow run terraform-apply.yml --ref main --repo luiarantes/IA-Infra-GCP-Project-01

gcp-down:
	@echo "🛑 Disparando Terraform Destroy no GCP via GitHub Actions..."
	gh workflow run terraform-destroy.yml --ref main --repo luiarantes/IA-Infra-GCP-Project-01 -f confirm="destroy"
