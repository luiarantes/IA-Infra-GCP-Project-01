# agents (fases 5 e 6)

Placeholder para os agentes de IA (Claude) responsáveis pelo self-healing.

Plano:
- **log-analyzer**: lê os logs/alertas coletados pela stack de observabilidade
  e identifica anomalias
- **triage**: usa Claude para diagnosticar a causa raiz, com contexto dos
  manifests e do Terraform relevantes
- **pr-creator**: gera o patch (YAML ou Terraform) e abre um Pull Request no
  GitHub com o fix proposto — nunca aplica direto; o merge exige aprovação
  humana no MVP

Onde roda no MVP: GitHub Actions agendado (`schedule:` trigger), sem custo
extra de infraestrutura. Migrar para Cloud Run Job/GKE CronJob é uma
evolução possível, não um requisito da fase 5/6.
