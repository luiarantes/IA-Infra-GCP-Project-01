# Topico usado para publicar notificacoes de orcamento; e a base para,
# futuramente, acionar uma Cloud Function que forca um destroy automatico
# se o gasto ultrapassar um limite critico (fase 7 do roadmap).
resource "google_pubsub_topic" "budget_alerts" {
  count   = var.enable_budget_alert ? 1 : 0
  project = var.project_id
  name    = "budget-alerts"
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
