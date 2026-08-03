# log-analyzer (fase 5)

Primeiro agente do projeto: detecta um possível problema e **diagnostica**
— não corrige nada ainda (isso é fase 6/7).

## Decisões de arquitetura

**Gatilho: manual (`workflow_dispatch`), não agendado.** Decidido de
propósito para não gerar custo recorrente de chamadas à API da Anthropic
enquanto o projeto ainda está em fase de teste. Migrar para `schedule:`
(ex: a cada 30 min) é trivial depois, se fizer sentido.

**Pre-check sem IA antes de acionar o Claude.** O workflow consulta 5
métricas diretamente — `restart_count`, `cpu`/`memory` (limit_utilization,
via a API clássica do Cloud Monitoring) e `http_5xx`/`latency` (via a API
compatível com PromQL, já que essas vêm do Managed Prometheus) — e só
invoca o Claude Code se alguma delas mostrar um valor fora do esperado.
Isso evita gastar tokens de API em execuções onde não há nada de errado,
e informa ao Claude quais categorias foram sinalizadas, para direcionar a
investigação.

**Implementação via Claude Code headless, não um script + chamada direta
à API.** O workflow instala o Claude Code CLI e roda em modo `-p` (print,
não-interativo) com a tarefa descrita em [`TASK.md`](TASK.md), dando a ele
acesso a um conjunto restrito de comandos via `--allowedTools`. A
vantagem: o próprio Claude decide quais comandos de diagnóstico rodar e
em que ordem, em vez de um script rígido pré-programado — mais parecido
com como um engenheiro investigaria de verdade.

**Saída: uma GitHub Issue, não um alerta por e-mail/Slack.** Fica
versionada, visível no repositório, e prepara o terreno pra fase 6 (o
agente de correção pode referenciar a issue no PR que abrir).

**Escopo de permissões**: só comandos de leitura + `gh issue create`. Sem
`kubectl apply/delete`, sem `gcloud ... create/update/delete`, sem
`gh pr create`. Mesmo sendo "só" um agente de diagnóstico, o princípio de
least privilege (já usado no resto do projeto) vale igual aqui — o agente
não deveria conseguir tecnicamente fazer mais do que seu papel exige,
independente do que o prompt manda ele não fazer.

## Pré-requisito

Secret `ANTHROPIC_API_KEY` configurado no repositório (Settings → Secrets
and variables → Actions) — ainda não estava configurado até a fase 4.

## Como testar

Actions → "Agent - Log Analyzer" → Run workflow. Ou:

```bash
gh workflow run agent-log-analyzer.yml
```

Se não houver restart recente, o job encerra rápido no pre-check (sem
custo de API da Anthropic). Para forçar um cenário de teste, gere um
crash de propósito primeiro (ver `observability/README.md`) e rode o
agente logo em seguida.
