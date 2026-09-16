# Chaos Engineering & Resiliência — AIOps Platform

Este módulo provê os mecanismos de injeção de falhas e engenharia de caos para validação da plataforma e treinamento de troubleshooting pelos operadores e agentes de IA.

---

## 1. Motores Disponíveis

### A. Chaos Mesh (CNCF Incubating) — Padrão Oficial
Com a evolução para **GKE Standard** (nós Spot dedicados com acesso completo a privilégios e GPU) e cluster local **Kind**, as restrições que existiam no antigo GKE Autopilot deixaram de existir. O Chaos Mesh atua como o motor oficial de caos nativo em Kubernetes através de Custom Resource Definitions (CRDs):

* `NetworkChaos`: Injeção de latência fina e perda de pacotes no tráfego de microsserviços.
* `HTTPChaos`: Injeção de códigos de erro HTTP (ex: 500) e abortos em endpoints.
* `StressChaos`: Contenção severa de CPU (Throttling) e esgotamento de memória (Slow OOM).
* `PodChaos`: Simulação de falhas de hardware e terminação abrupta de pods.

### B. Chaos Toolkit (Legado)
Mantido para execução pontual via Job Kubernetes padrão (`chaos-test/job.yaml`).

---

## 2. Injetor Randômico com Gabarito (`chaos_randomizer.py`)

Para evitar testes determinísticos e simular incidentes imprevistos de produção, o utilitário `chaos_randomizer.py` sorteia aleatoriamente um entre diversos cenários e registra o **Gabarito (Ground Truth)** em `.ground-truth/ground-truth.json`.

### Cenários no Catálogo:
1. **`latency-downstream`**: Injeta 3000ms de atraso nas respostas do `service-downstream`.
2. **`cascading-5xx`**: Injeta respostas HTTP 500 no `service-downstream`.
3. **`cpu-throttling`**: Estressa CPU em 95% no `service-api`.
4. **`slow-oom`**: Aloca memória progressivamente no `service-api` até forçar `OOMKilled` (Exit Code 137).
5. **`pod-kill`**: Mata pod do `gateway` avaliando resiliência do Deployment.

---

## 3. Como Executar

### Via GitHub Actions:
Dispare o workflow `Chaos Test` (`.github/workflows/chaos-test.yml`) via `workflow_dispatch`:
* `engine`: `chaos-mesh`
* `scenario`: `random` (ou selecione um específico)
* O arquivo `ground-truth.json` é publicado automaticamente como artefato da run para auditoria.

### Via Terminal Local (CLI):

```bash
# Instalar Chaos Mesh no cluster atual (Kind ou GKE)
./chaos-test/chaos-mesh/install.sh
```

```bash
# Sortear e aplicar um cenário aleatório gerando o Ground Truth
python3 chaos-test/chaos_randomizer.py --scenario random --action apply
```

```bash
# Inspecionar o gabarito ativo
python3 chaos-test/chaos_randomizer.py --action status
```

```bash
# Limpar experimentos de caos ativos
python3 chaos-test/chaos_randomizer.py --action clean
```

