#!/bin/bash
source .env

echo "👤 Creating Service Accounts..."

# Create Builder SA
gcloud iam service-accounts create $BUILDER_SA_NAME \
    --display-name="Travel Service Builder"

# Create Runtime SA
gcloud iam service-accounts create $RUNTIME_SA_NAME \
    --display-name="Travel Assistant Runtime"

echo "✅ Service Accounts Created:"
echo "- $BUILDER_SA_NAME@$GCP_PROJECT_ID.iam.gserviceaccount.com"
echo "- $RUNTIME_SA_NAME@$GCP_PROJECT_ID.iam.gserviceaccount.com"