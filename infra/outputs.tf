output "pubsub_topic_name" {
  description = "The name of the Pub/Sub topic created."
  value       = google_pubsub_topic.app_topic.name
}

output "pubsub_subscription_name" {
  description = "The name of the Pub/Sub subscription created."
  value       = google_pubsub_subscription.app_subscription.name
}

output "app_service_account_email" {
  description = "The email address of the application service account."
  value       = google_service_account.app_sa.email
}

output "cicd_service_account_email" {
  description = "The email address of the CI/CD service account."
  value       = google_service_account.cicd_sa.email
}

output "artifact_registry_repository_url" {
  description = "URL of the Artifact Registry repository."
  value       = "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/${google_artifact_registry_repository.app_repo.repository_id}"
}

output "github_wif_pool_id" {
  description = "The ID of the Workload Identity Pool for GitHub."
  value       = google_iam_workload_identity_pool.github_pool.name
}

output "db_password_secret_id" {
  description = "The resource ID of the DB password secret in Secret Manager."
  value       = google_secret_manager_secret.db_password_secret.id
}

output "workload_identity_pool_provider_name" {
  description = "The full name of the Workload Identity Pool Provider for GitHub Actions."
  value       = google_iam_workload_identity_pool_provider.github_provider.name
}
