#!/bin/bash

# Exit immediately if any command fails. This prevents subsequent commands from running if an error occurs.
set -e

GKE_CLUSTER_NAME="${GKE_CLUSTER_NAME}"
GKE_CLUSTER_REGION="${GKE_CLUSTER_REGION}"
PROJECT_ID="${PROJECT_ID}"
EXCLUSION_NAME="${EXCLUSION_NAME}"

# --- Dynamic Date Calculation ---
CURRENT_TIME_WITH_OFFSET=$(date +%Y-%m-%dT%H:%M:%S%z | sed 's/\([0-9][0-9]\)$/:\1/')
ONE_MONTH_LATER=$(date -d "+1 month" +%Y-%m-%dT%H:%M:%S%z | sed 's/\([0-9][0-9]\)$/:\1/')

# Assign the dynamically calculated values to the variables used by the gcloud command.
EXCLUSION_START="${CURRENT_TIME_WITH_OFFSET}"
EXCLUSION_END="${ONE_MONTH_LATER}"
EXCLUSION_SCOPE="no_upgrades" # This remains constant for your requirement.

# --- Basic Validation ---
# Check if the essential environment variables (passed from Cloud Run) are set.
if [ -z "${GKE_CLUSTER_NAME}" ] || \
   [ -z "${GKE_CLUSTER_REGION}" ] || \
   [ -z "${PROJECT_ID}" ] || \
   [ -z "${EXCLUSION_NAME}" ]; then
    echo "ERROR: One or more required environment variables are missing."
    echo "Please ensure GKE_CLUSTER_NAME, GKE_CLUSTER_REGION, PROJECT_ID, and EXCLUSION_NAME are set in Cloud Run."
    exit 1
fi

# --- Logging the Action ---
echo "Starting GKE maintenance exclusion update for cluster: ${GKE_CLUSTER_NAME}"
echo "  Project: ${PROJECT_ID}"
echo "  Region: ${GKE_CLUSTER_REGION}"
echo "  Exclusion Name: ${EXCLUSION_NAME}"
echo "  Calculated Start (from execution time): ${EXCLUSION_START}"
echo "  Calculated End (one month later): ${EXCLUSION_END}"
echo "  Scope: ${EXCLUSION_SCOPE}"

# --- Executing the gcloud Command (SIMULATION ONLY) ---
echo "Simulating gcloud command for GKE cluster update:"
echo "  gcloud container clusters update \"${GKE_CLUSTER_NAME}\" \\"
echo "      --region=\"${GKE_CLUSTER_REGION}\" \\"
echo "      --project=\"${PROJECT_ID}\" \\"
echo "      --add-maintenance-exclusion-name=\"${EXCLUSION_NAME}\" \\"
echo "      --add-maintenance-exclusion-start=\"${EXCLUSION_START}\" \\"
echo "      --add-maintenance-exclusion-end=\"${EXCLUSION_END}\" \\"
echo "      --add-maintenance-exclusion-scope=\"${EXCLUSION_SCOPE}\""

# Simulate a successful exit code for the gcloud command
exit 0

# --- Final Status Check ---
# Check the exit status of the previous command ($? is the exit code of the last command).
if [ $? -eq 0 ]; then
    echo "SUCCESS: GKE cluster maintenance exclusion updated successfully!"
else
    echo "ERROR: Failed to update GKE cluster maintenance exclusion. Check gcloud logs for details."
    exit 1 # Exit with an error code if the gcloud command failed.
fi