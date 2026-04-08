#!/bin/bash
# Load variables
source .env

echo "🌟 Creating Project: $GCP_PROJECT_ID..."

# Create the project
gcloud projects create $GCP_PROJECT_ID --name="Travel Assistant"

# Link Billing (Required for many APIs)
gcloud billing projects link $GCP_PROJECT_ID --billing-account=$BILLING_ACCOUNT_ID

# Set the project as the current context
gcloud config set project $GCP_PROJECT_ID

echo "🔗 Enabling APIs (This may take a minute)..."
gcloud services enable \
    compute.googleapis.com \
    cloudbuild.googleapis.com \
    cloudresourcemanager.googleapis.com \
    run.googleapis.com \
    aiplatform.googleapis.com \
    alloydb.googleapis.com \
    cloudkms.googleapis.com \
    maps-backend.googleapis.com \
    places-backend.googleapis.com
