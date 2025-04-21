provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

provider "google-beta" {
  project = var.gcp_project_id
  region  = var.gcp_region
}


data "google_client_config" "this" {}

data "google_container_cluster" "primary_cluster_data" {
  name     = google_container_cluster.primary.name
  location = google_container_cluster.primary.location
  project  = google_container_cluster.primary.project

}

# --- Configure Kubernetes Provider (Aliased) --- Using Data Sources
provider "kubernetes" {
  alias                  = "gke"
  host                   = "https://${data.google_container_cluster.primary_cluster_data.endpoint}"
  token                  = data.google_client_config.this.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.primary_cluster_data.master_auth[0].cluster_ca_certificate)

}

# --- Configure Helm Provider --- Using Data Sources
provider "helm" {
  kubernetes {
    host                   = "https://${data.google_container_cluster.primary_cluster_data.endpoint}"
    token                  = data.google_client_config.this.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.primary_cluster_data.master_auth[0].cluster_ca_certificate)
  }
}
