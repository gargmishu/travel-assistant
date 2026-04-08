#!/bin/bash
source .env

BUILDER_SA="$BUILDER_SA_NAME@$GCP_PROJECT_ID.iam.gserviceaccount.com"
RUNTIME_SA="$RUNTIME_SA_NAME@$GCP_PROJECT_ID.iam.gserviceaccount.com"

echo "👤 Deleting Service Accounts..."

gcloud iam service-accounts delete $BUILDER_SA
gcloud iam service-accounts delete $RUNTIME_SA

echo "✅ Service Accounts Deleted."