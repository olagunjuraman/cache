resource "google_service_account" "app_sa" {
  project      = var.gcp_project_id
  account_id   = var.app_service_account_id
  display_name = "Application Service Account"
}

resource "google_service_account" "cicd_sa" {
  project      = var.gcp_project_id
  account_id   = var.cicd_service_account_id
  display_name = "CI/CD Service Account"
}

resource "google_service_account_iam_member" "app_sa_ksa_binding" {
  for_each           = toset(["staging", "production"]) # Create bindings for both namespaces
  service_account_id = google_service_account.app_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.gcp_project_id}.svc.id.goog[${each.key}/${var.app_kubernetes_service_account_name}]"
}

resource "google_project_iam_member" "cicd_sa_gke_developer" {
  project = var.gcp_project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.cicd_sa.email}"
}

resource "google_project_iam_member" "cicd_sa_artifact_writer" {
  project = var.gcp_project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cicd_sa.email}"
}

resource "google_service_account_iam_member" "cicd_sa_pass_app_sa" {
  service_account_id = google_service_account.app_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cicd_sa.email}"
}

resource "google_iam_workload_identity_pool" "github_pool" {
  project                   = var.gcp_project_id
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Workload Identity Pool for GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  project                               = var.gcp_project_id
  workload_identity_pool_id             = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id    = "github-provider"
  display_name                          = "GitHub Actions Provider"
  description                           = "Workload Identity Provider for GitHub Actions"
  attribute_mapping                     = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }
  oidc = {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "cicd_sa_wif_binding" {
  service_account_id = google_service_account.cicd_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/${var.github_repo}"
}

resource "google_artifact_registry_repository" "app_repo" {
  provider      = google-beta
  project       = var.gcp_project_id
  location      = var.gcp_region
  repository_id = "app-images"
  description   = "Docker repository for the application images"
  format        = "DOCKER"

  depends_on = [google_project_service.artifactregistry]
}