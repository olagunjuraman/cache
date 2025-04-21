resource "google_pubsub_subscription" "app_subscription" {
  project    = var.gcp_project_id
  name       = var.pubsub_subscription_name
  topic      = google_pubsub_topic.app_topic.name

  ack_deadline_seconds = 60

  depends_on = [google_pubsub_topic.app_topic]
} 