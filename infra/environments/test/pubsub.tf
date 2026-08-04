# Fila do fluxo de microsservicos da fase 8 (gateway -> service-api ->
# fila -> service-worker -> service-downstream). Separada do topico
# budget-alerts (esse e' criado dentro do modulo budget, dedicado ao
# failsafe de custo da fase 7).
resource "google_pubsub_topic" "microservices_queue" {
  project = var.project_id
  name    = "microservices-queue"

  depends_on = [google_project_service.apis]
}

# Pull (nao push): o service-worker consome via streaming pull da
# biblioteca cliente, sem precisar expor endpoint HTTP nenhum para o
# Pub/Sub empurrar mensagens.
resource "google_pubsub_subscription" "microservices_queue_worker" {
  project = var.project_id
  name    = "microservices-queue-worker-pull"
  topic   = google_pubsub_topic.microservices_queue.id

  ack_deadline_seconds = 30
}
