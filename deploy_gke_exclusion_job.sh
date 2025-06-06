#!/bin/bash

# Exit immediately if any command fails.
set -e
set -x

# --- Configuration Variables ---
PROJECT_ID="euprdstage1"
GKE_CLUSTER_REGION="asia-southeast1" # Region where your GKE cluster is located
# GKE_CLUSTER_NAME will be read from cloud_run_job_config.yaml
# EXCLUSION_NAME will be read from cloud_run_job_config.yaml

# Cloud Run Job specific configurations
CLOUD_RUN_JOB_REGION="asia-southeast1" # Region where the Cloud Run Job will be deployed (can be same as GKE)
ARTIFACT_REGISTRY_REPO_NAME="eup"
IMAGE_NAME="gke-maintenance-updater"
IMAGE_TAG="latest"
SERVICE_ACCOUNT_NAME="jenkins"
SCHEDULER_JOB_NAME="gke-maintenance-exclusion-scheduler"
SCHEDULER_SCHEDULE="0 0 1 * *" # Example: Run at 00:00 on the 1st of every month

SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
FULL_IMAGE_PATH="${CLOUD_RUN_JOB_REGION}-docker.pkg.dev/${PROJECT_ID}/${ARTIFACT_REGISTRY_REPO_NAME}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "--- Starting GKE Maintenance Exclusion Setup Script ---"
echo "Project ID: ${PROJECT_ID}"
echo "GKE Cluster Region: ${GKE_CLUSTER_REGION}"
echo "Cloud Run Job Region: ${CLOUD_RUN_JOB_REGION}"
echo "Image Path: ${FULL_IMAGE_PATH}"
echo "Service Account: ${SERVICE_ACCOUNT_EMAIL}"
echo "----------------------------------------------------"

# --- 1. Validate Required Files ---
echo "Validating presence of required files..."
if [ ! -f "run.sh" ]; then
    echo "ERROR: 'run.sh' not found in the current directory."
    exit 1
fi
if [ ! -f "Dockerfile" ]; then
    echo "ERROR: 'Dockerfile' not found in the current directory."
    exit 1
fi
if [ ! -f "cloud_run_job_config.yaml" ]; then
    echo "ERROR: 'cloud_run_job_config.yaml' not found in the current directory."
    exit 1
fi
echo "All required files are present."

# --- 2. Enable Artifact Registry API ---
echo "Enabling Artifact Registry API..."
gcloud services enable artifactregistry.googleapis.com --project="${PROJECT_ID}"

# --- 3. Configure Docker to use Artifact Registry ---
echo "Configuring Docker for Artifact Registry in ${CLOUD_RUN_JOB_REGION}..."
gcloud auth configure-docker "${CLOUD_RUN_JOB_REGION}-docker.pkg.dev"

# --- 5. Build the Docker Image ---
echo "Building Docker image: ${FULL_IMAGE_PATH}..."
docker build -t "${FULL_IMAGE_PATH}" .

# --- 6. Push the Docker Image ---
echo "Pushing Docker image to Artifact Registry..."
docker push "${FULL_IMAGE_PATH}"

# --- 9. Deploy the Cloud Run Job ---
echo "Deploying Cloud Run Job 'gke-maintenance-exclusion-job' from cloud_run_job_config.yaml..."
gcloud run jobs replace cloud_run_job_config.yaml \
    --region="${CLOUD_RUN_JOB_REGION}" \
    --project="${PROJECT_ID}"

# --- 11. Create Cloud Scheduler Job ---
echo "Creating Cloud Scheduler job '${SCHEDULER_JOB_NAME}' to trigger the Cloud Run Job monthly..."
gcloud scheduler jobs create http "${SCHEDULER_JOB_NAME}" \
    --project "${PROJECT_ID}" \
    --location "${CLOUD_RUN_JOB_REGION}" \
    --schedule "${SCHEDULER_SCHEDULE}" \
    --uri "https://${CLOUD_RUN_JOB_REGION}-run.googleapis.com/v1/projects/${PROJECT_ID}/locations/${CLOUD_RUN_JOB_REGION}/jobs/gke-maintenance-exclusion-job:run" \
    --http-method POST \
    --oidc-service-account-email "${SERVICE_ACCOUNT_EMAIL}" \
    --oidc-token-audience "https://${CLOUD_RUN_JOB_REGION}-run.googleapis.com/v1/projects/${PROJECT_ID}/locations/${CLOUD_RUN_JOB_REGION}/jobs/gke-maintenance-exclusion-job:run" \
    --attempt-deadline="1h" \
    --description="Monthly trigger for GKE maintenance exclusion Cloud Run Job" || echo "Cloud Scheduler job already exists or creation failed, proceeding..."


echo "--- Script Finished ---"
echo "Your GKE maintenance exclusion Cloud Run Job has been set up!"
echo "You can monitor its executions and logs in the GCP Console:"
echo "https://console.cloud.google.com/run/jobs/gke-maintenance-exclusion-job/executions?project=${PROJECT_ID}&region=${CLOUD_RUN_JOB_REGION}"
echo ""
echo "To manually execute the job for testing:"
echo "gcloud run jobs execute gke-maintenance-exclusion-job --region=${CLOUD_RUN_JOB_REGION} --project=${PROJECT_ID}"
echo ""
echo "To view the Cloud Scheduler job:"
echo "https://console.cloud.google.com/cloudscheduler?project=${PROJECT_ID}"
echo "----------------------------------------------------"