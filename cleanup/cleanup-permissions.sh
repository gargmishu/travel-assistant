#!/bin/bash
source .env

BUILDER_SA="$BUILDER_SA_NAME@$GCP_PROJECT_ID.iam.gserviceaccount.com"
RUNTIME_SA="$RUNTIME_SA_NAME@$GCP_PROJECT_ID.iam.gserviceaccount.com"
USER_EMAIL=$(gcloud config get-value account)

echo "🛡️ Revoking IAM Permissions..."

# Revoke Builder Roles
BUILDER_ROLES=(
    "roles/logging.logWriter",
    "roles/artifactregistry.writer",
    "roles/storage.admin")
for role in "${BUILDER_ROLES[@]}"; do
    gcloud projects remove-iam-policy-binding $GCP_PROJECT_ID \
        --member="serviceAccount:$BUILDER_SA" --role="$role" --quiet > /dev/null 2>&1
done

# Revoke Runtime Roles
RUNTIME_ROLES=(
    "roles/aiplatform.user"
    "roles/storage.objectAdmin"
    "roles/serviceusage.serviceUsageConsumer"
    "roles/alloydb.client"
)
for role in "${RUNTIME_ROLES[@]}"; do
    gcloud projects remove-iam-policy-binding $GCP_PROJECT_ID \
        --member="serviceAccount:$RUNTIME_SA" --role="$role" --quiet > /dev/null 2>&1
done


# Revoke ActAs
gcloud iam service-accounts remove-iam-policy-binding $BUILDER_SA \
    --member="user:$USER_EMAIL" --role="roles/iam.serviceAccountUser" --quiet > /dev/null 2>&1

gcloud iam service-accounts remove-iam-policy-binding $RUNTIME_SA \
    --member="user:$USER_EMAIL" --role="roles/iam.serviceAccountUser" --quiet > /dev/null 2>&1

echo "✅ Permissions Revoked."