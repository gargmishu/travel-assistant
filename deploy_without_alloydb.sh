#!/bin/bash

# 1. Ensure variables are set correctly
source .env
BUILDER_SA="$BUILDER_SA_NAME@$GCP_PROJECT_ID.iam.gserviceaccount.com"
RUNTIME_SA="$RUNTIME_SA_NAME@$GCP_PROJECT_ID.iam.gserviceaccount.com"


# 2. Ensure we use GCP_PROJECT_ID from the .env file
# and set the gcloud context so you don't accidentally deploy to the wrong place
if [ -z "$GCP_PROJECT_ID" ]; then
    echo "❌ GCP_PROJECT_ID is not defined in .env"
    exit 1
fi
gcloud config set project $GCP_PROJECT_ID


# 3. Execute deployment
echo "gcloud run deploy travel-assistant \
   --source . \
   --region asia-south1 \
   --allow-unauthenticated \
   --build-service-account="projects/${GCP_PROJECT_ID}/serviceAccounts/${BUILDER_SA}" \
   --service-account="${RUNTIME_SA}" \
   --clear-base-image"
gcloud run deploy travel-assistant \
   --source . \
   --region asia-south1 \
   --allow-unauthenticated \
   --build-service-account="projects/${GCP_PROJECT_ID}/serviceAccounts/${BUILDER_SA}" \
   --service-account="${RUNTIME_SA}" \
   --clear-base-image
