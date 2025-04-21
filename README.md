# GCP Infrastructure Setup for Cache Take Home Assessment

This repository contains the infrastructure code (Terraform), application code, Kubernetes manifests, and CI/CD pipeline configuration for the Cache DevOps assessment.

## Architecture Overview

*   **Networking:** Separate VPCs for Staging (`staging-vpc`) and Production (`production-vpc`) are created, though the GKE cluster currently resides only in the Production VPC for simplicity. Each VPC has a dedicated subnet.
*   **Compute:** A regional GKE cluster (`cache-assessment-cluster`) hosts the application in the Production VPC.
*   **Databases:** A Cloud SQL for PostgreSQL instance (`cache-assessment-db`) is provisioned with a private IP within the Production VPC.
*   **Messaging:** A Pub/Sub topic (`cache-assessment-topic`) and subscription (`cache-assessment-sub`) are created for asynchronous message handling.
*   **Application:** A Python Flask application (`/app`) provides `/health` and `/message` endpoints. It publishes to Pub/Sub and writes to PostgreSQL upon receiving a message.
*   **Containerization:** The app is containerized using Docker (`/app/Dockerfile`) and images are stored in Google Artifact Registry (`app-images` repo).
*   **Deployment:** Kubernetes manifests (`/kubernetes`) using Kustomize define the application deployment. Overlays for `staging` and `production` namespaces handle environment-specific configurations (replicas, environment variables).
*   **CI/CD:** A GitHub Actions workflow (`.github/workflows/deploy.yml`) triggers on pushes to `main`. It uses Workload Identity Federation to authenticate to GCP, builds the Docker image, pushes it to Artifact Registry, substitutes configuration from Terraform outputs into Kustomize overlays, and deploys the application to the appropriate GKE namespace (`production` for `main` branch, `staging` otherwise).
*   **Security:**
    *   IAM Service Accounts are used for the application (`app-sa`) and CI/CD (`cicd-sa`) following least privilege.
    *   Workload Identity is used for GKE pods to securely access GCP APIs.
    *   Workload Identity Federation is used for GitHub Actions to securely authenticate (requires manual setup step).
    *   Secrets (DB password) are stored in GCP Secret Manager (`db-password`).
*   **Logging:** A self-hosted ELK stack (Elasticsearch, Logstash, Kibana) and Fluent Bit are deployed to the `logging` namespace within GKE via Helm charts. Fluent Bit collects container logs and forwards them to Logstash, which processes them and sends them to Elasticsearch. Logs can be viewed via the Kibana dashboard.

## Setup Instructions

1.  **Prerequisites:**
    *   Google Cloud SDK (`gcloud`) installed and authenticated.
    *   Terraform installed.
    *   Git installed.
    *   A GCP project with billing enabled.
    *   A GitHub repository where this code resides.

2.  **Clone Repository:**
    ```bash
    git clone <your-repo-url>
    cd <repo-directory>
    ```

3.  **Configure Terraform:**
    *   Navigate to the `infra` directory: `cd infra`
    *   Create a `terraform.tfvars` file (or set environment variables `TF_VAR_gcp_project_id`, `TF_VAR_github_repo`).
    *   Add your GCP Project ID: `gcp_project_id = "your-gcp-project-id"`
    *   Add your GitHub repository (owner/repo): `github_repo = "your-github-owner/your-repo-name"`

4.  **Provision Infrastructure:**
    *   Initialize Terraform: `terraform init`
    *   Review the plan: `terraform plan -var-file=terraform.tfvars`
    *   Apply the changes: `terraform apply -var-file=terraform.tfvars -auto-approve`
    *   Note the outputs, especially those needed for GitHub Secrets.

5.  **Configure GitHub Secrets/Variables:**
    *   Go to your GitHub repository settings -> Secrets and variables -> Actions.
    *   Create the following **Secrets** (using values from Terraform output or your environment):
        *   `GCP_PROJECT_ID`: Your GCP project ID.
        *   `GCP_REGION`: The GCP region used (e.g., `us-central1`).
        *   `GKE_CLUSTER_NAME`: Output `gke_cluster_name`.
        *   `GAR_REPO_URL`: Output `artifact_registry_repository_url`.
        *   `WIF_POOL_PROVIDER`: Output `github_wif_provider_id` (full resource name).
        *   `CICD_SERVICE_ACCOUNT`: Output `cicd_service_account_email`.
        *   `DB_USER_TF`: Output `db_user`.
        *   `DB_NAME_TF`: Output `db_name`.
        *   `DB_INSTANCE_CONNECTION_NAME_TF`: Output `db_instance_connection_name`.
        *   `PUBSUB_TOPIC_ID_TF`: Output `pubsub_topic_name`.

6.  **Trigger Deployment:**
    *   Commit and push changes to the `main` branch (for production) or another branch (for staging).
    *   Monitor the GitHub Actions workflow execution.

7.  **Access Application & Kibana:**
    *   Get the External IP for Kibana (may take a minute):
        ```bash
        kubectl get service -n logging kibana-kibana-lb-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
        ```
    *   Open the Kibana IP in your browser. Navigate to Discover to see logs.
    *   Port-forward the application service:
        ```bash
        # For production:
        kubectl port-forward service/cache-app-service 8080:80 -n production
        # For staging:
        kubectl port-forward service/cache-app-service 8081:80 -n staging
        ```
    *   Send a message:
        ```bash
        curl -X POST -H "Content-Type: application/json" \
             -d '{"message":"Hello from ELK assessment!"}' \
             http://localhost:8080/message # Or 8081 for staging
        ```
    *   Check logs in Kibana (allow a short delay for processing). Also check application pod logs directly: `kubectl logs -l app=cache-app -n <namespace> -f --tail=100`.
    *   Check the database (you might need to connect via Cloud Shell or configure proxy access).

## Components

*   **`/infra`**: Terraform code for GCP resources.
*   **`/app`**: Sample Python Flask application code and Dockerfile.
*   **`/kubernetes`**: Kubernetes manifests (using Kustomize) for deploying the application to GKE.
*   **`.github/workflows`**: GitHub Actions workflow for CI/CD.
*   **`infra-docs.md`**: Documentation on security, IAM, secrets, and SOC 2 alignment. 