# Infrastructure Overview

This document outlines the key components, security configurations, and operational aspects of the infrastructure managed by Terraform.

## 1. Identity and Access Management (IAM)

Access is managed following the principle of least privilege.

**Key Service Accounts:**

*   **Application Service Account (`app-sa`):** Used by the application running in GKE.
    *   `roles/iam.workloadIdentityUser`: Link to Kubernetes Service Account (`app-ksa`) via Workload Identity.
    *   `roles/pubsub.publisher`: Publish to `cache-assessment-topic`.
    *   `roles/cloudsql.client`: Connect to the Cloud SQL database.
    *   `roles/secretmanager.secretAccessor`: Read secrets (e.g., DB password) from Secret Manager.

*   **CI/CD Service Account (`cicd-sa`):** Used by the GitHub Actions workflow.
    *   `roles/iam.workloadIdentityUser`: Authenticate GitHub Actions via Workload Identity Federation (WIF).
    *   `roles/container.developer`: Deploy to and manage resources within GKE.
    *   `roles/artifactregistry.writer`: Push images to Artifact Registry.
    *   `roles/iam.serviceAccountUser` (on `app-sa`): Allow CI/CD to manage `app-sa` bindings if necessary.
    *   `roles/secretmanager.secretAccessor`: *Note: Broad access, potentially reducible.* Allows accessing secrets if needed during CI/CD.

*   **GKE Node Service Account:** Default Compute Engine service account used by GKE nodes (standard logging/monitoring roles). Can be replaced with a custom, more restricted SA if required.

**Authentication Methods:**

*   **Workload Identity (GKE):** Links the Kubernetes Service Account (`app-ksa`) to the GCP Service Account (`app-sa`). This allows pods to securely authenticate to GCP APIs without exporting service account keys.
*   **Workload Identity Federation (CI/CD):** Allows GitHub Actions runners (for the configured repository) to impersonate the `cicd-sa` using short-lived OIDC tokens, avoiding static GCP credentials in GitHub.

## 2. Secret Management

*   **Platform:** GCP Secret Manager.
*   **Managed Secrets:**
    *   `db-password`: Password for the `appuser` Cloud SQL user.

*   **Application Access:**
    1.  Pods run as the `app-ksa` Kubernetes Service Account.
    2.  Workload Identity links `app-ksa` to `app-sa`.
    3.  `app-sa` has `secretmanager.secretAccessor` permissions.
    4.  Application uses GCP client libraries, which leverage Workload Identity to automatically fetch the `db-password` from Secret Manager at runtime.
    *   *Note:* This assumes a mechanism like the Secrets Store CSI Driver or External Secrets Operator is configured in GKE to sync the GCP secret to a Kubernetes Secret or volume mount available to the pod, or the application directly uses the Secret Manager client library.

*   **CI/CD Access:**
    *   The workflow authenticates as `cicd-sa` via WIF.
    *   Currently, `cicd-sa` has `secretmanager.secretAccessor`. This is typically *not* needed for the application's runtime secrets (like the DB password) but might be required if the build process itself needs secrets. Evaluate if this permission is necessary.

## 3. Logging and Auditing

*   **Infrastructure Auditing:** Google Cloud Audit Logs track administrative changes (e.g., modifications to GKE, Cloud SQL, IAM). Reviewed via Cloud Console (Logging -> Cloud Audit Logs).
*   **Application Logging:** A self-hosted ELK stack (Elasticsearch, Logstash, Kibana) runs within GKE. Fluent Bit (as a DaemonSet) forwards container logs to Logstash for processing and storage. Reviewed via the Kibana UI.
*   **SOC 2 Considerations:** GCP Audit Logs provide evidence for change tracking. Application logs within ELK support monitoring and incident investigation (requires appropriate configuration, like alerts). Infrastructure as Code (IaC) and CI/CD workflows provide controlled change management.

## 4. Networking

*   **Virtual Private Clouds (VPCs):**
    *   `staging-vpc`: 10.10.0.0/16
    *   `production-vpc`: 10.20.0.0/16
*   **Subnets:**
    *   `staging-subnet`: 10.10.1.0/24
    *   `production-subnet`: 10.20.1.0/24
*   **Firewall Rules:**
    *   Currently includes basic `allow-internal` rules (`staging-allow-internal`, `production-allow-internal`).
    *   **Security Note:** These rules are permissive. Production environments require stricter rules (e.g., limiting ingress/egress, allowing only necessary ports like LB health checks, GKE control plane access).
*   **Cloud SQL Connectivity:** Uses Private IP within the production VPC, established via VPC Network Peering (`servicenetworking` connection).
*   **GKE Networking:** VPC-native cluster operating within `production-vpc` and `production-subnet`.

## 5. Secure Access (Bastion/VPN)

*   **Current State:** No dedicated Bastion Host or VPN is provisioned via this Terraform configuration.
*   **GKE Access:** Primarily managed via IAM (`roles/container.developer` grants `kubectl` access). GKE Authorized Networks can further restrict control plane access to specific IP ranges. Direct SSH access to nodes should be avoided or heavily restricted.
*   **Auditing Access:** GCP Audit Logs track administrative actions (including `kubectl` usage if audit logging is enabled). If a Bastion host were used, tools like OS Login (with audit logs) or forwarding SSH logs to ELK would be necessary.

## 6. SOC 2 Alignment Summary

This configuration supports various SOC 2 controls:

*   **CC6 (Access Control):** Least privilege IAM, network segmentation (VPCs/Firewalls), secure secret management, Workload Identity/WIF limiting credential exposure.
*   **CC7 (System Operations):** Change control via IaC/CI/CD, infrastructure audit logs, application log aggregation (ELK), infrastructure monitoring (Cloud Monitoring/GKE metrics).
*   **A1 (Availability):** GKE regional cluster, Cloud SQL HA, application replica sets, Cloud SQL backups.
*   **C1 (Confidentiality):** Encryption at rest/in transit (GCP defaults), access controls via IAM and Secret Manager.

