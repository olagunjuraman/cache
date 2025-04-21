variable "db_instance_name" {
  description = "Name for the Cloud SQL instance."
  type        = string
  default     = "cache-assessment-db"
}

variable "db_name" {
  description = "Name of the database to create."
  type        = string
  default     = "appdb"
}

variable "db_user" {
  description = "Username for the default database user."
  type        = string
  default     = "appuser"
}

# Note: DB password will be generated and stored in Secret Manager
variable "db_tier" {
  description = "Machine type for the Cloud SQL instance."
  type        = string
  default     = "db-f1-micro" # Use a small tier for assessment
}

variable "pubsub_topic_name" {
  description = "Name for the Pub/Sub topic."
  type        = string
  default     = "cache-assessment-topic"
}

variable "pubsub_subscription_name" {
  description = "Name for the Pub/Sub subscription."
  type        = string
  default     = "cache-assessment-sub"
}

variable "app_service_account_id" {
  description = "The ID for the application service account."
  type        = string
  default     = "app-sa"
}

variable "cicd_service_account_id" {
  description = "The ID for the CI/CD service account."
  type        = string
  default     = "cicd-sa"
}

variable "github_repo" {
  description = "GitHub repository in the format `owner/repo`. Used for Workload Identity Federation."
  type        = string
  # Example: default = "my-github-org/my-repo"
  # Replace with your actual GitHub repo
}

variable "github_wif_provider_id" {
  description = "The ID for the Workload Identity Pool Provider for GitHub."
  type        = string
  default     = "github-provider"
}

variable "github_wif_pool_id" {
  description = "The ID for the Workload Identity Pool for GitHub."
  type        = string
  default     = "github-pool"
}

variable "gcp_project_id" {
  description = "The GCP project ID."
  type        = string
  # No default, must be provided via tfvars or environment variable
}

variable "gcp_region" {
  description = "The GCP region for resources."
  type        = string
  default     = "us-central1" # You can change this default if needed
}

variable "staging_vpc_cidr" {
  description = "CIDR block for the staging VPC."
  type        = string
  default     = "10.10.0.0/16"
}

variable "production_vpc_cidr" {
  description = "CIDR block for the production VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "staging_subnet_cidr" {
  description = "CIDR block for the staging GKE subnet."
  type        = string
  default     = "10.10.1.0/24"
}

variable "production_subnet_cidr" {
  description = "CIDR block for the production GKE subnet."
  type        = string
  default     = "10.20.1.0/24"
}

variable "cluster_name" {
  description = "The name for the GKE cluster."
  type        = string
  default     = "cache-assessment-cluster"
}

variable "gke_machine_type" {
  description = "Machine type for GKE nodes."
  type        = string
  default     = "e2-medium"
}

variable "gke_initial_node_count" {
  description = "Initial number of nodes per zone in the GKE cluster node pool."
  type        = number
  default     = 1 # We'll scale the deployment later, this is per zone for regional cluster
}

variable "gke_oauth_scopes" {
  description = "OAuth scopes for GKE node service accounts."
  type        = list(string)
  default = [
    "https://www.googleapis.com/auth/cloud-platform" # Broad scope, refine if needed
  ]
} 