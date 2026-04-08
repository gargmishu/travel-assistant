#!/bin/bash

# ==============================================================================
# SCRIPT: setup-network.sh
# DESCRIPTION: Creates a Custom VPC, Subnet, Private Service Access (for AlloyDB),
#              and essential Firewall rules for Google Cloud.
# ==============================================================================


# --- 1. Configuration (Edit .env file as needed) ---
# Load variables
source .env

# Ensure we use GCP_PROJECT_ID from the .env file
# and set the gcloud context so you don't accidentally deploy to the wrong place
if [ -z "$GCP_PROJECT_ID" ]; then
    echo "❌ GCP_PROJECT_ID is not defined in .env"
    exit 1
fi
gcloud config set project $GCP_PROJECT_ID


echo "------------------------------------------------------------"
echo "🚀 Starting Network Deployment for Project: $GCP_PROJECT_ID"
echo "------------------------------------------------------------"

# --- 2. Enable Required APIs ---
echo "⚙️  Checking Required APIs..."
for service in servicenetworking.googleapis.com compute.googleapis.com vpcaccess.googleapis.com; do
    if ! gcloud services list --enabled --filter="name:$service" --format="value(config.name)" | grep -q "$service"; then
        echo "Enabling $service..."
        gcloud services enable "$service"
    else
        echo "API $service is already enabled."
    fi
done

# --- 3. Create the VPC (Custom Mode) ---
if ! gcloud compute networks describe "$VPC_NAME" --format="get(name)" > /dev/null 2>&1; then
    echo "🌐 Creating VPC: $VPC_NAME..."

    # Custom mode gives you full control over IP address management.
    # bgp-routing-mode: When set to global, every Cloud Router in the VPC can see and share routes with every other
    # Cloud Router in that VPC, regardless of the region; i.e. a route learned from an on-premises location in 
    # us-east1 is instantly available to resources in asia-east1, europe-north1, and all other regions within that 
    # network.
    gcloud compute networks create "$VPC_NAME" \
        --subnet-mode=custom \
        --bgp-routing-mode=global
else
    echo "🌐 VPC $VPC_NAME already exists. Skipping."
fi

# --- 4. Create the Subnet ---
# This is for your local resources (Cloud Run Direct Egress, VMs, AlloyDb etc.)
if ! gcloud compute networks subnets describe "$SUBNET_NAME" --region="$REGION" --format="get(name)" > /dev/null 2>&1; then
    echo "📍 Creating Subnet: $SUBNET_NAME in $REGION..."

    # This setting allows VM instances without external IP addresses to communicate with Google APIs and services (like Cloud Storage or BigQuery) over Google's internal network. It effectively secures your environment by keeping traffic off the public internet while maintaining access to managed cloud resources.
    gcloud compute networks subnets create $SUBNET_NAME \
        --network=$VPC_NAME \
        --range=$SUBNET_RANGE \
        --region=$REGION \
        --enable-private-ip-google-access
else
    echo "📍 Subnet $SUBNET_NAME already exists. Skipping."
fi


# --- 5. Reserve IP Range for Private Service Access ---
# This /16 block is used for services like AlloyDB, Cloud SQL, and Memorystore.
if ! gcloud compute addresses describe "$RESERVED_RANGE_NAME" --global --format="get(name)" > /dev/null 2>&1; then
    echo "💎 Reserving IP range: $RESERVED_RANGE_NAME..."
    gcloud compute addresses create "$RESERVED_RANGE_NAME" \
        --global \
        --purpose=VPC_PEERING \
        --prefix-length=16 \
        --network="$VPC_NAME"
else
    echo "💎 IP Range $RESERVED_RANGE_NAME already reserved. Skipping."
fi


# --- 6. Create the Peering Connection (The "Magic" Step) ---
# This connects your VPC to the Google-managed service network.
# Peering check is slightly different; we check if the peering name exists on the network
if ! gcloud compute networks peerings list --network="$VPC_NAME" --format="value(peerings.name)" | grep -q "servicenetworking-googleapis-com"; then
    echo "🤝 Establishing Private Service Connection..."
    gcloud services vpc-peerings connect \
        --service=servicenetworking.googleapis.com \
        --ranges=$RESERVED_RANGE_NAME \
        --network=$VPC_NAME
    echo "Waiting for Peering to stabilize..."
    sleep 10
else
    echo "🤝 VPC Peering for Service Networking already exists. Skipping."
fi

# CRITICAL: Give Service Networking time to stabilize before AlloyDB hits it
echo "Waiting for Peering to stabilize..."
sleep 10


echo "------------------------------------------------------------"
echo "🐘 Starting AlloyDB Provisioning..."
echo "------------------------------------------------------------"

# --- 7. Create the AlloyDB Cluster ---
# The cluster is the logical container for your nodes.
if ! gcloud alloydb clusters describe "$CLUSTER_ID" --region="$REGION" > /dev/null 2>&1; then
    echo "🛠️  Creating AlloyDB Cluster: $CLUSTER_ID..."
    gcloud alloydb clusters create $CLUSTER_ID \
        --password=$DB_PASSWORD \
        --network=$VPC_NAME \
        --region=$REGION
else
    echo "🛠️  AlloyDB Cluster $CLUSTER_ID already exists. Skipping."
fi

# --- 8. Create the AlloyDB Primary Instance ---
# This is the actual compute resource (the database engine).
# We use 2 vCPUs as requested (the minimum for many production tiers).
if ! gcloud alloydb instances describe "$INSTANCE_ID" --cluster="$CLUSTER_ID" --region="$REGION" > /dev/null 2>&1; then
    echo "⚙️  Creating Primary Instance: $INSTANCE_ID..."
    gcloud alloydb instances create $INSTANCE_ID \
        --cluster=$CLUSTER_ID \
        --region=$REGION \
        --instance-type=PRIMARY \
        --cpu-count=2
else
    echo "⚙️  AlloyDB Instance $INSTANCE_ID already exists. Skipping."
fi

