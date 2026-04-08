#!/bin/bash
source .env

BUILDER_SA="$BUILDER_SA_NAME@$GCP_PROJECT_ID.iam.gserviceaccount.com"
RUNTIME_SA="$RUNTIME_SA_NAME@$GCP_PROJECT_ID.iam.gserviceaccount.com"
USER_EMAIL=$(gcloud config get-value account)

echo "🛡️ Applying IAM Roles..."

# Builder Roles
BUILDER_ROLES=(
    "roles/logging.logWriter"
    "roles/artifactregistry.writer"
    "roles/storage.admin"
)

for role in "${BUILDER_ROLES[@]}"; do
    gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
        --member="serviceAccount:$BUILDER_SA" --role="$role" --quiet
done

# Runtime Roles
RUNTIME_ROLES=(
    "roles/aiplatform.user"
    "roles/storage.objectAdmin"
    "roles/serviceusage.serviceUsageConsumer"
    "roles/alloydb.client"
    "roles/vpcaccess.user"
)

for role in "${RUNTIME_ROLES[@]}"; do
    gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
        --member="serviceAccount:$RUNTIME_SA" --role="$role" --quiet
done

# User ActAs Permission
# Allow yourself to use the Builder account
gcloud iam service-accounts add-iam-policy-binding $BUILDER_SA \
    --member="user:$USER_EMAIL" --role="roles/iam.serviceAccountUser" --quiet

# Allow yourself to use the Runtime account
gcloud iam service-accounts add-iam-policy-binding $RUNTIME_SA \
    --member="user:$USER_EMAIL" --role="roles/iam.serviceAccountUser" --quiet

echo "✅ Permissions Synced for $USER_EMAIL"