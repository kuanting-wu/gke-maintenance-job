#!/bin/bash

# Exit immediately if any command fails.
set -e
set -x

# --- Global Configuration Variables ---
PROJECT_ID="euprdstage1"
# CLOUD_RUN_JOB_REGION can be common for all jobs if desired, or configured per job.
CLOUD_RUN_JOB_REGION="asia-southeast1"
ARTIFACT_REGISTRY_REGION="asia" # Note: Artifact Registry region for docker.pkg.dev
ARTIFACT_REGISTRY_REPO_NAME="eup"
IMAGE_NAME="eup-gke-maintenance-updater"
IMAGE_TAG="latest"
SERVICE_ACCOUNT_NAME="jenkins" # This service account is used by the Cloud Run Job
SCHEDULER_SERVICE_ACCOUNT_NAME="cloud-run" # This service account is used by the Cloud Run Job
SCHEDULER_SCHEDULE="0 0 * * 1" # Common schedule for all jobs (e.g., every Monday at midnight)

SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
SCHEDULER_SERVICE_ACCOUNT_EMAIL="${SCHEDULER_SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" # Using the same service account for Cloud Schedule
FULL_IMAGE_PATH="${ARTIFACT_REGISTRY_REGION}-docker.pkg.dev/${PROJECT_ID}/${ARTIFACT_REGISTRY_REPO_NAME}/${IMAGE_NAME}:${IMAGE_TAG}"
CLOUD_RUN_JOB_CONFIG_DIR="cloud_run_job_configs" # New variable for the config directory

echo "--- Starting GKE Maintenance Exclusion Setup Script ---"
echo "Project ID: ${PROJECT_ID}"
echo "Cloud Run Job Region (Common): ${CLOUD_RUN_JOB_REGION}"
echo "Artifact Registry Region: ${ARTIFACT_REGISTRY_REGION}"
echo "Image Path: ${FULL_IMAGE_PATH}"
echo "Service Account for Cloud Run Jobs: ${SERVICE_ACCOUNT_EMAIL}"
echo "Cloud Run Job Config Directory: ${CLOUD_RUN_JOB_CONFIG_DIR}"
echo "----------------------------------------------------"

# --- 1. Validate Required Files ---
echo "Validating presence of required files and directory..."
if [ ! -f "run.sh" ]; then
    echo "ERROR: 'run.sh' not found in the current directory."
    exit 1
fi
if [ ! -f "Dockerfile" ]; then
    echo "ERROR: 'Dockerfile' not found in the current directory."
    exit 1
fi
if [ ! -d "${CLOUD_RUN_JOB_CONFIG_DIR}" ]; then # Check if directory exists
    echo "ERROR: '${CLOUD_RUN_JOB_CONFIG_DIR}' directory not found."
    exit 1
fi
echo "All required files and directories are present."

# --- 2. Enable Artifact Registry API ---
echo "Enabling Artifact Registry API..."
gcloud services enable artifactregistry.googleapis.com --project="${PROJECT_ID}"

# --- 3. Configure Docker to use Artifact Registry ---
echo "Configuring Docker for Artifact Registry in ${ARTIFACT_REGISTRY_REGION}..."
gcloud auth configure-docker "${ARTIFACT_REGISTRY_REGION}-docker.pkg.dev"

# --- 4. Build the Docker Image ---
# This image is generic and will be used by all Cloud Run Jobs
echo "Building Docker image: ${FULL_IMAGE_PATH}..."
docker build -t "${FULL_IMAGE_PATH}" .

# --- 5. Push the Docker Image ---
echo "Pushing Docker image to Artifact Registry..."
docker push "${FULL_IMAGE_PATH}"

# --- 6. Enable the Cloud Run Job API---
echo "Enabling run.googleapis.com..."
gcloud services enable run.googleapis.com --project="${PROJECT_ID}"

# --- 7. Iterate and Deploy Cloud Run Jobs and Schedulers ---
# Find all YAML files in the config directory
CONFIG_FILES=$(find "${CLOUD_RUN_JOB_CONFIG_DIR}" -maxdepth 1 -name "*.yaml" | sort)

if [ -z "$CONFIG_FILES" ]; then
    echo "No Cloud Run Job configuration YAML files found in '${CLOUD_RUN_JOB_CONFIG_DIR}'. Exiting."
    exit 1
fi

for CONFIG_FILE in $CONFIG_FILES; do
    JOB_NAME=$(grep -A 1 '^metadata:' "$CONFIG_FILE" | grep 'name:' | head -n 1 | sed 's/.*name:[[:space:]]*//')
    if [ -z "$JOB_NAME" ]; then
        echo "WARNING: Could not extract job name from $CONFIG_FILE. Skipping."
        continue
    fi
    SCHEDULER_JOB_NAME="${JOB_NAME}-scheduler" # Unique scheduler name per job

    echo "--- Processing Configuration for Job: ${JOB_NAME} (from ${CONFIG_FILE}) ---"

    # --- Deploy the Cloud Run Job ---
    echo "Deploying Cloud Run Job '${JOB_NAME}' from ${CONFIG_FILE}..."
    gcloud run jobs replace "${CONFIG_FILE}" \
        --region="${CLOUD_RUN_JOB_REGION}" \
        --project="${PROJECT_ID}" \
        --quiet # Add --quiet to suppress interactive prompts for --allow-unauthenticated as it's a job

    echo "--- Finished Processing Job: ${JOB_NAME} ---"
done

echo "--- Script Finished ---"
echo "All GKE maintenance exclusion Cloud Run Jobs have been set up!"
echo "You can monitor their executions and logs in the GCP Console:"
echo "https://console.cloud.google.com/run/jobs?project=${PROJECT_ID}&region=${CLOUD_RUN_JOB_REGION}"
echo ""
echo "To manually execute a specific job (replace JOB_NAME):"
echo "gcloud run jobs execute JOB_NAME --region=${CLOUD_RUN_JOB_REGION} --project=${PROJECT_ID}"
echo ""
echo "To view Cloud Scheduler jobs:"
echo "https://console.cloud.google.com/cloudscheduler?project=${PROJECT_ID}"
echo "----------------------------------------------------"
