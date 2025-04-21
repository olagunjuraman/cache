resource "google_secret_manager_secret" "db_password_secret" {
  project   = var.gcp_project_id
  secret_id = "db-password"

  replication {
    user_managed {
      replicas {
        location = var.gcp_region
      }
    }
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "db_password_secret_version" {
  secret      = google_secret_manager_secret.db_password_secret.id
  secret_data = random_password.db_password.result

  depends_on = [
    google_sql_user.app_user
  ]
}

# Allow App SA to access the DB password secret
resource "google_secret_manager_secret_iam_member" "app_sa_db_password_access" {
  project   = google_secret_manager_secret.db_password_secret.project
  secret_id = google_secret_manager_secret.db_password_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app_sa.email}"

  depends_on = [google_secret_manager_secret.db_password_secret]
}

