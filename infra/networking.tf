# --- Staging Network ---

resource "google_compute_network" "staging_vpc" {
  name                    = "staging-vpc"
  project                 = var.gcp_project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "staging_subnet" {
  name          = "staging-subnet"
  project       = var.gcp_project_id
  ip_cidr_range = var.staging_subnet_cidr
  region        = var.gcp_region
  network       = google_compute_network.staging_vpc.id
}

# --- Production Network ---

resource "google_compute_network" "production_vpc" {
  name                    = "production-vpc"
  project                 = var.gcp_project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "production_subnet" {
  name          = "production-subnet"
  project       = var.gcp_project_id
  ip_cidr_range = var.production_subnet_cidr
  region        = var.gcp_region
  network       = google_compute_network.production_vpc.id

  secondary_ip_range {
    range_name    = "gke-pods-range"
    ip_cidr_range = "192.168.0.0/16"
  }

  secondary_ip_range {
    range_name    = "gke-services-range"
    ip_cidr_range = "192.169.0.0/20"
  }
}

# --- Firewall Rules (Example: Allow internal traffic) ---

# Allow internal traffic within Staging VPC
resource "google_compute_firewall" "staging_allow_internal" {
  name    = "staging-allow-internal"
  network = google_compute_network.staging_vpc.name
  project = var.gcp_project_id

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [var.staging_vpc_cidr]
}

# Allow internal traffic within Production VPC
resource "google_compute_firewall" "production_allow_internal" {
  name    = "production-allow-internal"
  network = google_compute_network.production_vpc.name
  project = var.gcp_project_id

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [var.production_vpc_cidr]
} 