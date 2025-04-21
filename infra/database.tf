resource "random_password" "db_password" {
  length  = 16
  special = true
}

resource "google_sql_database_instance" "primary" {
  provider           = google-beta
  project            = var.gcp_project_id
  name               = var.db_instance_name
  region             = var.gcp_region
  database_version   = "POSTGRES_14"

  settings {
    tier = var.db_tier

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.production_vpc.id
    }

    backup_configuration {
      enabled = true
    }

    availability_type = "REGIONAL"
  }

  depends_on = [google_service_networking_connection.private_vpc_connection]

  deletion_protection = false
}

resource "google_sql_database" "app_db" {
  project  = var.gcp_project_id
  instance = google_sql_database_instance.primary.name
  name     = var.db_name
}

resource "google_sql_user" "app_user" {
  project  = var.gcp_project_id
  instance = google_sql_database_instance.primary.name
  name     = var.db_user
  password = random_password.db_password.result
}