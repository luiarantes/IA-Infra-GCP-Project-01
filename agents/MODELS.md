# Arquitetura de Modelos de IA e Inferência Local — AIOps Platform

Este documento detalha o funcionamento do motor de inferência local (**Ollama**), os critérios técnicos para seleção de Large Language Models (LLMs) no ecossistema de SRE/DevOps, e a fundamentação da escolha dos modelos homologados na plataforma.

---

## 1. O que é o Ollama e por que adotá-lo?

O **Ollama** atua como uma camada de abstração e gerenciamento de modelos de inteligência artificial locais — conceitualmente equivalente ao papel do **Docker** para containers de software:

- **Empacotamento e Quantização**: Gerencia downloads de modelos abertos no formato GGUF quantizados (ex: 4-bit, 8-bit), permitindo que modelos com bilhões de parâmetros caibam na memória RAM/VRAM de estações de trabalho comuns.
- **Aceleração de Hardware Nativamente Otimizada**: Roda sobre o motor de inferência C++ (`llama.cpp`), utilizando aceleração direta via **Metal** (Apple Silicon) ou **CUDA** (NVIDIA GPUs), com consumo mínimo de CPU.
- **API Unificada e Compatibilidade OpenAI**: Expõe um servidor HTTP local na porta `11434` com endpoints padronizados (`/v1/chat/completions` e `/api/chat`). Isso permite que os scripts de automação interajam com o modelo local usando a mesma interface padronizada utilizada por provedores comerciais em nuvem.
- **Privacidade e Custo Zero**: Nenhum log de aplicação, manifest de infraestrutura ou métrica sai do ambiente local. A execução é 100% offline, sem custos por token ou dependência de conectividade externa.

---

## 2. Critérios de Avaliação para Modelos em SRE e Infraestrutura

A resolução autônoma de incidentes de plataforma e Kubernetes (**Troubleshooting/Self-Healing**) difere substancialmente da geração de texto genérico. Exige três competências centrais:

1. **Sensibilidade Cirúrgica a Sintaxe (YAML, HCL e Código)**:
   - Manifests Kubernetes dependem rigidamente de espaçamento e indentação. Um erro de formatação invalida o deployment.
   - O modelo precisa conhecer tipos de recursos, versões de API (`apps/v1`, `networking.k8s.io/v1`), convenções de probes (`httpGet`, `exec`, `tcpSocket`) e geração de patches em formato de diff unificado (`git diff`).
2. **Raciocínio Dedutivo de Causa-Raiz (Root Cause Analysis - RCA)**:
   - Capacidade de correlacionar múltiplos sinais isolados (ex: *Exit Code 137* nos logs do pod + *métrica de memória em 100%* no Prometheus = *o kernel do Linux acionou o OOM Killer porque o container ultrapassou o `limits.memory`*).
   - Dedução lógica estrita, minimizando alucinações técnicas.
3. **Pegada de Memória (Footprint de RAM/VRAM)**:
   - O modelo deve coabitar a máquina do operador junto ao Docker Desktop, o cluster Kubernetes local (Kind) e a stack de observabilidade sem estrangular a memória do sistema.

---

## 3. Análise dos Modelos Homologados

### 3.1 `qwen2.5-coder:7b` (Modelo Padrão da Plataforma)
- **Origem**: Alibaba Cloud.
- **Perfil**: Especialista em Engenharia de Software, DevOps e Infraestrutura como Código (IaC).
- **Justificativa da Escolha**:
  - Treinado em larga escala com repositórios de código real, manifests Kubernetes, Dockerfiles, Terraform e scripts shell.
  - Excepcional capacidade de gerar patches Git limpos e precisos, alterando cirurgicamente apenas as linhas necessárias no manifest ou código.
  - Janela de contexto ampla (suporta 32k tokens nativos), permitindo ingestão de dumps longos de `kubectl describe` e centenas de linhas de logs do Loki.
  - **Consumo de Memória**: ~4.5 GB a 5.0 GB de RAM na quantização de 4-bit (`q4_k_m`).

### 3.2 `deepseek-r1:8b` (Especialista em Diagnóstico Dedutivo)
- **Origem**: DeepSeek.
- **Perfil**: Raciocínio Puro e Chain-of-Thought (CoT).
- **Justificativa da Escolha**:
  - Processa o diagnóstico gerando uma cadeia de raciocínio explícita (etapas de verificação de hipóteses antes de emitir o parecer final).
  - Ideal para o **Agente 1 (`log-analyzer`)** em incidentes de alta complexidade (ex: falhas em cascata entre microsserviços, deadlocks e timeouts distribuídos).
  - Elimina conclusões precipitadas ao simular a linha de investigação de um engenheiro SRE sênior.
  - **Consumo de Memória**: ~5.0 GB a 5.5 GB de RAM.

### 3.3 `llama3.2:3b` (Operador Ultra-Leve)
- **Origem**: Meta.
- **Perfil**: Inferência Rápida e Baixo Consumo de Recursos.
- **Justificativa da Escolha**:
  - Projetado para estações de trabalho com restrições severas de hardware (ex: notebooks com 8 GB ou 16 GB totais de RAM compartilhada).
  - Respostas instantâneas para tarefas focadas em classificação e triagem de logs.
  - **Consumo de Memória**: ~2.0 GB a 2.5 GB de RAM.

---

## 4. Matriz Comparativa de Modelos

| Critério | `qwen2.5-coder:7b` | `deepseek-r1:8b` | `llama3.2:3b` |
| :--- | :--- | :--- | :--- |
| **Foco Primário** | Código, YAML e Geração de Patches | Raciocínio Lógico Dedutivo (RCA) | Eficiência e Baixa Latência |
| **Papel no Loop AIOps** | **Agente 2 (`pr-creator`)** / Diagnóstico | **Agente 1 (`log-analyzer`)** | Triagem / Ambientes Restritos |
| **Precisão em Kubernetes/IaC** | ⭐⭐⭐⭐⭐ (Excelente) | ⭐⭐⭐⭐ (Muito Bom) | ⭐⭐⭐ (Básico a Intermediário) |
| **Análise de Causa-Raiz (RCA)**| ⭐⭐⭐⭐ (Muito Bom) | ⭐⭐⭐⭐⭐ (Excepcional) | ⭐⭐⭐ (Básico) |
| **Uso de RAM / VRAM** | ~4.8 GB | ~5.2 GB | ~2.2 GB |
| **Tempo Médio de Inferência** | Rápido (~25-35 tokens/s) | Moderado (~15-20 tokens/s) | Ultra-rápido (~45-60 tokens/s) |

---

## 5. Configuração e Variáveis de Ambiente

O motor de execução dos agentes (`agents/engine/agent_runner.py`) consome as seguintes variáveis para selecionar o modelo:

| Variável | Valores Suportados | Padrão | Descrição |
| :--- | :--- | :--- | :--- |
| `AIOPS_AI_PROVIDER` | `ollama`, `openai`, `gemini`, `claude` | `ollama` | Backend de inferência utilizado |
| `AIOPS_OLLAMA_HOST` | URL HTTP | `http://localhost:11434` | Endpoint do servidor Ollama local |
| `AIOPS_OLLAMA_MODEL` | Nome do modelo registrado | `qwen2.5-coder:7b` | Modelo carregado para o raciocínio |
| `AIOPS_LOCAL_TRACKER` | `github`, `file` | `github` | Destino das issues (`gh` ou arquivo local) |
