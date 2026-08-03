# verify-fix (fase 7, parte A)

Fecha o loop de self-healing: depois que um humano aprova e mergeia um PR
aberto pelo `pr-creator` (label `agent-fix`), este workflow confirma se o
problema original realmente parou de acontecer.

## Decisões de arquitetura

**Sem Claude, de propósito.** Diferente dos outros dois agentes, este é
uma checagem puramente mecânica: reconsulta a mesma métrica de
`restart_count` já usada nas fases 5/6 e compara um número antes/depois.
Não há julgamento a fazer aqui — não faria sentido gastar uma chamada de
API de IA para algo que um `if` resolve. Nem toda etapa de um sistema de
IA precisa ser, ela mesma, "IA".

**Gatilho: merge de um PR rotulado `agent-fix`.** O `pr-creator` (fase 6)
foi ajustado para aplicar esse label em todo PR que abrir. Sem ele, este
workflow rodaria em qualquer merge do repositório, não só nos fixes
propostos por agente.

**Espera fixa de 5 minutos antes de checar.** O merge do PR também
dispara o `deploy-app.yml` (que já existia, sem mudança nenhuma — só
reaproveitado). Em vez de tentar encadear os dois workflows via eventos
(`workflow_run`), que exigiria correlacionar SHA de commit com PR de
forma mais complexa, um `sleep 300` simples dá tempo do deploy terminar
antes da checagem. Mais simples que "correto" no sentido acadêmico, mas
suficiente e fácil de entender.

**Resultado**: comenta na issue original (que o GitHub já fechou
automaticamente via `Closes #N` no merge) confirmando que o problema
sumiu, ou **reabre a issue** se os restarts continuarem — sinalizando que
o fix não resolveu de verdade e precisa de atenção humana de novo.
