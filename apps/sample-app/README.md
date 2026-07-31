# sample-app (fase 3)

Placeholder para a aplicação de teste que será implantada no GKE.

Ideia para o MVP: usar uma app já pronta e conhecida para chaos/observability
(ex. [podinfo](https://github.com/stefanprodan/podinfo)) em vez de escrever
uma do zero — ela já expõe métricas, logs estruturados e endpoints para
simular falhas, o que ajuda a testar o loop de self-healing sem precisar
construir o "alvo" também.

Conteúdo desta pasta na fase 3: manifests Kubernetes (ou Helm chart) para
deploy da app no cluster criado pela fase 1.
