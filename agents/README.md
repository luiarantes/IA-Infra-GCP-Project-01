# agents (fases 5 e 6)

Agentes de IA (Claude Code, rodando em modo headless via GitHub Actions)
responsáveis por detectar problemas e propor correções.

- **[log-analyzer](log-analyzer/)** (fase 5): detecta um possível
  incidente (via um pre-check barato, sem IA, sobre as métricas da fase
  4), investiga com Claude Code, e abre uma GitHub Issue com o
  diagnóstico — rotulada `agent-finding`. Não corrige nada.
- **[pr-creator](pr-creator/)** (fase 6): acionado automaticamente quando
  uma issue é rotulada `agent-finding`. Avalia o diagnóstico e decide se
  existe uma correção de código razoável — se sim, abre um Pull Request;
  se não, comenta explicando por quê. Nunca aplica nada diretamente.

Cada agente roda isolado, com escopo de permissões restrito ao que sua
etapa exige (least privilege também vale para autonomia de IA). Merge e
aplicação do PR ficam para uma etapa futura, com aprovação humana
obrigatória.
