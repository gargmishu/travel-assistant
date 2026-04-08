#!/bin/bash
source .env

gcloud alloydb instances list \
    --cluster=$CLUSTER_ID \
    --region=$REGION 

ip_address=$(gcloud alloydb instances list \
    --cluster=$CLUSTER_ID \
    --region=$REGION \
    --format="value(ipAddress)")

echo "ip_address= $ip_address"