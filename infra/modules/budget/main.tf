# Topico usado para publicar notificacoes de orcamento.
resource "google_pubsub_topic" "budget_alerts" {
  count   = var.enable_budget_alert ? 1 : 0
  project = var.project_id
  name    = "budget-alerts"
}

# Subscription pull (nao push) - o workflow de failsafe de custo (fase 7)
# le mensagens daqui periodicamente via GitHub Actions, usando a mesma
# identidade WIF do resto do projeto. Deliberadamente pull em vez de push
# para nao precisar de uma Cloud Function nem de credencial nova
# (o GitHub Actions ja tem acesso via WIF, ninguem "empurra" nada pra ele).
resource "google_pubsub_subscription" "budget_alerts_pull" {
  count   = var.enable_budget_alert ? 1 : 0
  project = var.project_id
  name    = "budget-alerts-failsafe-pull"
  topic   = google_pubsub_topic.budget_alerts[0].id

  # Mensagens de orcamento nao sao urgentes por natureza - retencao
  # generosa e ack_deadline curto (o workflow so precisa ler e decidir)
  message_retention_duration = "1200s"
  ack_deadline_seconds       = 30
}

# Requer que a service account do Terraform tenha roles/billing.costsManager
# (ou billing.admin) na billing account - concedido manualmente, fora do
# escopo de IAM do projeto. Veja infra/bootstrap/README.md.
resource "google_billing_budget" "this" {
  count           = var.enable_budget_alert ? 1 : 0
  billing_account = var.billing_account_id
  display_name    = var.budget_display_name

  budget_filter {
    projects = ["projects/${var.project_number}"]
  }

  amount {
    specified_amount {
      currency_code = var.budget_currency_code
      units         = var.budget_amount
    }
  }

  dynamic "threshold_rules" {
    for_each = var.alert_thresholds
    content {
      threshold_percent = threshold_rules.value
    }
  }

  all_updates_rule {
    pubsub_topic                   = google_pubsub_topic.budget_alerts[0].id
    disable_default_iam_recipients = false
  }
}
