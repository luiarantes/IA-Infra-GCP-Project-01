output "budget_id" {
  value = var.enable_budget_alert ? google_billing_budget.this[0].id : null
}

output "pubsub_topic_id" {
  value = var.enable_budget_alert ? google_pubsub_topic.budget_alerts[0].id : null
}
