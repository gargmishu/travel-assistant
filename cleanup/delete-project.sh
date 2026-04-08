#!/bin/bash
source .env

echo "🚫 Disabling APIs (This may take a minute)..."
gcloud services disable \
    places-backend.googleapis.com \
    maps-backend.googleapis.com \
    cloudkms.googleapis.com \
    alloydb.googleapis.com \
    aiplatform.googleapis.com \
    run.googleapis.com \
    cloudresourcemanager.googleapis.com \
    cloudbuild.googleapis.com \
    compute.googleapis.com \
    --force

echo "⚠️  DANGER: You are about to delete the project: $GCP_PROJECT_ID"
echo "This will destroy ALL resources (AlloyDB, Cloud Run, Storage, etc.)"
read -p "Type the Project ID to confirm: " CONFIRM_ID

if [ "$CONFIRM_ID" == "$GCP_PROJECT_ID" ]; then
    echo "🧨 Deleting Project..."
    gcloud projects delete $GCP_PROJECT_ID --quiet
    echo "✅ Project $GCP_PROJECT_ID has been scheduled for deletion."
else
    echo "❌ Confirmation failed. Project not deleted."
    exit 1
fi