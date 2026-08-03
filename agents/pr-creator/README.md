# pr-creator (fase 6)

Segundo agente do projeto: pega o diagnóstico da fase 5 (a GitHub Issue
com o label `agent-finding`) e decide se existe uma correção de código
razoável a propor. Ainda **não aplica nada** — no máximo abre um PR.
Aprovação humana + merge + apply automatizado ficam para a fase 7.

## Decisões de arquitetura

**Gatilho: automático, ao rotular a issue** (`on: issues: types:
[labeled]`, filtrado por `agent-finding`). Isso encadeia com a fase 5 sem
custo de polling — só roda quando existe um diagnóstico real (a fase 5
por sua vez só roda o Claude quando o pre-check encontra algo). O
resultado é uma cadeia "crash → issue → PR" totalmente orientada a
eventos reais, nunca a um relógio.

**Pode decidir não fazer nada.** Nem todo diagnóstico tem uma correção de
código sensata (o nosso caso de teste — alguém chamando `/panic` de
propósito — é exatamente isso: não há bug para corrigir). O agente é
instruído a comentar na issue explicando a ausência de fix em vez de abrir
um PR de baixo valor só para parecer produtivo. Essa é uma decisão de
design deliberada: um agente que "sempre propõe algo" é pior que um que
sabe dizer "não sei" ou "não há nada a corrigir aqui".

**Escopo de edição restrito a `apps/` e `observability/`.** O agente não
pode alterar `infra/`, os próprios workflows, ou a pasta `agents/` — não
deveria conseguir modificar as regras que o restringem, mesmo que
tecnicamente "faça sentido" para o problema em questão.

**Sem acesso ao cluster.** Diferente da fase 5, este agente só lê a issue
e os arquivos do repositório — não autentica no GCP/GKE. Todo o contexto
necessário já deveria estar na issue escrita pelo log-analyzer.

## Pré-requisito

Este agente depende da fase 5 aplicar o label `agent-finding` em toda
issue de diagnóstico que abrir — sem o label, o workflow desta fase nunca
dispara.

## Como testar

Rode a fase 5 até ela abrir uma issue com o label `agent-finding` — o
workflow desta fase deve disparar sozinho logo em seguida. Para
acompanhar:

```bash
gh run list --workflow=agent-pr-creator.yml
```
