#!/bin/bash

# 1. Ensure variables are set correctly
source .env
BUILDER_SA="$BUILDER_SA_NAME@$GCP_PROJECT_ID.iam.gserviceaccount.com"
RUNTIME_SA="$RUNTIME_SA_NAME@$GCP_PROJECT_ID.iam.gserviceaccount.com"

# Construct a comma-separated list for Cloud Run
ENV_VARS="GCP_PROJECT_ID=$GCP_PROJECT_ID,"
ENV_VARS+="REGION=$REGION,"
ENV_VARS+="CLUSTER_ID=$CLUSTER_ID,"
ENV_VARS+="INSTANCE_ID=$INSTANCE_ID,"
ENV_VARS+="DB_USER=$DB_USER,"
ENV_VARS+="DB_PASSWORD=$DB_PASSWORD,"
ENV_VARS+="DB_NAME=$DB_NAME,"
ENV_VARS+="GEMINI_MODEL=$GEMINI_MODEL,"
ENV_VARS+="DB_REGION=$DB_REGION"


# 2. Ensure we use GCP_PROJECT_ID from the .env file
# and set the gcloud context so you don't accidentally deploy to the wrong place
if [ -z "$GCP_PROJECT_ID" ]; then
    echo "❌ GCP_PROJECT_ID is not defined in .env"
    exit 1
fi
gcloud config set project $GCP_PROJECT_ID


# 3. Execute deployment
gcloud run deploy travel-assistant \
   --source . \
   --region asia-south1 \
   --network=$VPC_NAME  \
   --subnet=$SUBNET_NAME  \
   --allow-unauthenticated \
   --vpc-egress=all-traffic \
   --set-env-vars="$ENV_VARS" \
   --build-service-account="projects/${GCP_PROJECT_ID}/serviceAccounts/${BUILDER_SA}" \
   --service-account="${RUNTIME_SA}" \
   --clear-base-image 


