#!/bin/bash

echo "Creating Amazon Macie Classification Job for ${ACCOUNT_NAME:-default}..."

REGION=${AWS_DEFAULT_REGION:-us-west-2}

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if Macie is enabled
STATUS=$(aws macie2 get-macie-session --region $REGION 2>/dev/null | jq -r .status)
if [ "$STATUS" != "ENABLED" ]; then
    echo -e "${RED}Amazon Macie is not enabled. Please run ./enable-macie.sh first.${NC}"
    exit 1
fi

echo -e "\n=== Available S3 Buckets for Classification ==="
BUCKETS=$(aws macie2 describe-buckets --region $REGION --query 'buckets[].bucketName' --output json)
echo "$BUCKETS" | jq -r '.[]' | nl -v 0

# Get bucket count
BUCKET_COUNT=$(echo "$BUCKETS" | jq length)
if [ "$BUCKET_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}No S3 buckets found for classification.${NC}"
    exit 0
fi

# Interactive bucket selection
echo -e "\n${BLUE}Select bucket for classification (enter number, or 'all' for all buckets):${NC}"
read -r SELECTION

if [ "$SELECTION" = "all" ]; then
    echo -e "${YELLOW}Creating classification job for all buckets...${NC}"
    SELECTED_BUCKETS="$BUCKETS"
else
    if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -ge "$BUCKET_COUNT" ]; then
        echo -e "${RED}Invalid selection. Please enter a valid number.${NC}"
        exit 1
    fi
    SELECTED_BUCKET=$(echo "$BUCKETS" | jq -r ".[$SELECTION]")
    SELECTED_BUCKETS="[\"$SELECTED_BUCKET\"]"
fi

# Create S3 job scope
S3_JOB_SCOPE=$(echo "$SELECTED_BUCKETS" | jq -r 'map({"bucket": {"name": .}}) | {s3JobDefinition: {bucketDefinitions: .}}')

# Job name with timestamp
JOB_NAME="sensitive-data-discovery-$(date +%Y%m%d-%H%M%S)"

echo -e "\n=== Creating Classification Job: $JOB_NAME ==="

# Create the classification job
aws macie2 create-classification-job \
    --job-type ONE_TIME \
    --name "$JOB_NAME" \
    --description "Sensitive data discovery job for account ${ACCOUNT_NAME}" \
    --s3-job-definition "$S3_JOB_SCOPE" \
    --region $REGION

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Classification job created successfully!${NC}"
    
    echo -e "\n=== Job Details ==="
    echo "Job Name: $JOB_NAME"
    echo "Job Type: ONE_TIME"
    echo "Selected Buckets: $(echo "$SELECTED_BUCKETS" | jq -r '.[]' | tr '\n' ' ')"
    
    # List current jobs
    echo -e "\n=== Current Classification Jobs ==="
    aws macie2 list-classification-jobs \
        --region $REGION \
        --query 'items[].{Name: name, Status: jobStatus, CreatedAt: createdAt}' \
        --output table
    
    echo -e "\n${BLUE}Monitor job progress with: ./get-macie-findings.sh${NC}"
    echo -e "${BLUE}Check findings in Security Hub integration${NC}"
else
    echo -e "${RED}Failed to create classification job${NC}"
    exit 1
fi
