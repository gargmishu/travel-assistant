#!/bin/bash

# ==============================================================================
# SCRIPT: delete-database.sh
# DESCRIPTION: Deletes the AlloyDB Instance and Cluster.
# PRE-REQUISITE: Ensure no applications are actively writing to the DB.
# ==============================================================================

# --- 1. Configuration (Edit .env file as needed) ---
# Load variables
source .env

# Ensure we use GCP_PROJECT_ID from the .env file
# and set the gcloud context so you don't accidentally cleanup on the wrong place
if [ -z "$GCP_PROJECT_ID" ]; then
    echo "❌ GCP_PROJECT_ID is not defined in .env"
    exit 1
fi
gcloud config set project $GCP_PROJECT_ID

echo "------------------------------------------------------------"
echo "⚠️  Starting AlloyDB Deletion..."
echo "------------------------------------------------------------"

# --- 2. Delete the AlloyDB Instance ---
# You MUST delete all instances before the cluster can be removed.
if gcloud alloydb instances describe "$INSTANCE_ID" --cluster="$CLUSTER_ID" --region="$REGION" > /dev/null 2>&1; then
    echo "🗑️  Deleting AlloyDB Instance: $INSTANCE_ID..."
    # --quiet skips the confirmation prompt
    gcloud alloydb instances delete $INSTANCE_ID \
    --cluster=$CLUSTER_ID \
    --region=$REGION \
    --quiet
else
    echo "ℹ️  AlloyDB Instance $INSTANCE_ID not found. Skipping."
fi

# --- 3. Delete the AlloyDB Cluster ---
if gcloud alloydb clusters describe "$CLUSTER_ID" --region="$REGION" > /dev/null 2>&1; then
    echo "🗑️  Deleting AlloyDB Cluster: $CLUSTER_ID..."
    gcloud alloydb clusters delete $CLUSTER_ID --region=$REGION --quiet
else
    echo "ℹ️  AlloyDB Cluster $CLUSTER_ID not found. Skipping."
fi

# --- 4. Delete VPC Peering ---
# Note: This removes the 'bridge' to Google Services (PSA)
# This is necessary before deleting the reserved IP range or VPC
PEERING_NAME="servicenetworking-googleapis-com"
if gcloud compute networks peerings list --network="$VPC_NAME" --format="value(peerings.name)" | grep -q "$PEERING_NAME"; then
    echo "🤝 Removing Private Service Connection (Peering)..."
    # Note: Peering deletion can sometimes be slow to propagate in GCP APIs
    gcloud compute networks peerings delete $PEERING_NAME --network=$VPC_NAME --quiet
    echo "Waiting for Peering removal to propagate..."
    sleep 20
else
    echo "ℹ️  VPC Peering not found. Skipping."
fi

# --- 5. Delete Reserved IP Range ---
if gcloud compute addresses describe "$RESERVED_RANGE_NAME" --global > /dev/null 2>&1; then
    echo "💎 Releasing Reserved IP Range: $RESERVED_RANGE_NAME..."
    gcloud compute addresses delete $RESERVED_RANGE_NAME --global --quiet
else
    echo "ℹ️  Reserved IP Range $RESERVED_RANGE_NAME not found. Skipping."
fi

# --- 6. Delete Subnet ---
if gcloud compute networks subnets describe "$SUBNET_NAME" --region="$REGION" > /dev/null 2>&1; then
    echo "📍 Deleting Subnet: $SUBNET_NAME..."
    gcloud compute networks subnets delete $SUBNET_NAME --region=$REGION --quiet
else
    echo "ℹ️  Subnet $SUBNET_NAME not found. Skipping."
fi

# --- 7. Delete VPC ---
if gcloud compute networks describe "$VPC_NAME" > /dev/null 2>&1; then
    echo "🌐 Deleting VPC: $VPC_NAME..."
    gcloud compute networks delete $VPC_NAME --quiet
else
    echo "ℹ️  VPC $VPC_NAME not found. Skipping."
fi

echo "------------------------------------------------------------"
echo "✅ Teardown Complete."
echo "------------------------------------------------------------"
"""