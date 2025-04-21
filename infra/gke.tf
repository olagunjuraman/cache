resource "google_container_cluster" "primary" {
  name     = "cache-assessment-cluster"
  location = "us-central1-a"
  project  = var.gcp_project_id

  network    = google_compute_network.production_vpc.id

  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods-range"
    services_secondary_range_name = "gke-services-range"
  }

  initial_node_count = 1
  remove_default_node_pool = true

  workload_identity_config {
    workload_pool = "${var.gcp_project_id}.svc.id.goog"
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    gce_persistent_disk_csi_driver_config {
       enabled = true
    }
  }

  logging_service    = "none"
  monitoring_service = "none"
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "default-pool"
  project    = var.gcp_project_id
  location   = "us-central1-a"
  cluster    = google_container_cluster.primary.name

  node_count = 1

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = "e2-standard-2"
    disk_size_gb = 50
    disk_type    = "pd-standard"
    preemptible  = false

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      "pool" = "default-pool"
    }

    tags = ["gke-node", "cache-assessment-node"]
  }
}

resource "kubernetes_namespace" "staging" {
  provider = kubernetes.gke
  metadata {
    name = "staging"
  }
  depends_on = [google_container_node_pool.primary_nodes]
}

resource "kubernetes_namespace" "production" {
  provider = kubernetes.gke
  metadata {
    name = "production"
  }
  depends_on = [google_container_node_pool.primary_nodes]
}