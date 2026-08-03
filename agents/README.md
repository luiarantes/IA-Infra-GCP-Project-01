# agents (fases 5 a 7)

Agentes responsáveis por detectar problemas, propor correções, e
confirmar que elas funcionaram. Os dois primeiros usam Claude Code
rodando em modo headless via GitHub Actions; o terceiro é uma checagem
mecânica, sem IA.

- **[log-analyzer](log-analyzer/)** (fase 5): detecta um possível
  incidente (via um pre-check barato, sem IA, sobre as métricas da fase
  4), investiga com Claude Code, e abre uma GitHub Issue com o
  diagnóstico — rotulada `agent-finding`. Não corrige nada.
- **[pr-creator](pr-creator/)** (fase 6): acionado automaticamente quando
  uma issue é rotulada `agent-finding`. Avalia o diagnóstico e decide se
  existe uma correção de código razoável — se sim, abre um Pull Request
  rotulado `agent-fix`; se não, comenta explicando por quê. Nunca aplica
  nada diretamente.
- **[verify-fix](verify-fix/)** (fase 7): acionado quando um PR rotulado
  `agent-fix` é mergeado. Espera o deploy automático acontecer, reconsulta
  a métrica original, e confirma na issue se o problema parou — ou reabre
  se não parou. Sem Claude: é uma comparação de números, não um
  julgamento.

Cada agente roda isolado, com escopo de permissões restrito ao que sua
etapa exige (least privilege também vale para autonomia de IA). Merge do
PR sempre exige aprovação humana — os agentes nunca aplicam nada na
infraestrutura sozinhos.
