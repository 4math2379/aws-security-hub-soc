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
STATUS=$(aws macie2 get-macie-session --region $REGION --query 'status' --output text 2>/dev/null)
if [ "$STATUS" != "ENABLED" ]; then
    echo -e "${RED}Amazon Macie is not enabled. Please run ./enable-macie.sh first.${NC}"
    exit 1
fi

echo -e "\n=== Available S3 Buckets for Classification ==="
# Get bucket names as text list
BUCKET_NAMES=$(aws s3api list-buckets --query 'Buckets[].Name' --output text)
if [ -z "$BUCKET_NAMES" ]; then
    echo -e "${YELLOW}No S3 buckets found for classification.${NC}"
    exit 0
fi

# Display buckets with numbers and privacy status
echo "Available buckets:"
echo "$BUCKET_NAMES" | tr '\t' '\n' | nl -v 0

echo -e "\n=== Bucket Privacy Status ==="
echo "Checking bucket privacy settings..."
for bucket in $BUCKET_NAMES; do
    # Check if bucket has public access block
    PUBLIC_ACCESS=$(aws s3api get-public-access-block --bucket "$bucket" --query 'PublicAccessBlockConfiguration.BlockPublicAcls' --output text 2>/dev/null)
    if [ "$PUBLIC_ACCESS" = "True" ]; then
        echo -e "${GREEN}✓ $bucket - Private (recommended for classification)${NC}"
    else
        echo -e "${YELLOW}⚠ $bucket - Public or no access block configured${NC}"
    fi
done

echo -e "\n${BLUE}Note: Private buckets are recommended for sensitive data discovery.${NC}"

# Interactive bucket selection
echo -e "\n${BLUE}Select bucket for classification (enter number, or 'all' for all buckets):${NC}"
read -r SELECTION

# Convert to array for easier handling
BUCKET_ARRAY=($BUCKET_NAMES)
BUCKET_COUNT=${#BUCKET_ARRAY[@]}

if [ "$SELECTION" = "all" ]; then
    echo -e "${YELLOW}Creating classification job for all buckets...${NC}"
    SELECTED_BUCKETS="${BUCKET_ARRAY[@]}"
else
    if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -ge "$BUCKET_COUNT" ]; then
        echo -e "${RED}Invalid selection. Please enter a valid number.${NC}"
        exit 1
    fi
    SELECTED_BUCKETS="${BUCKET_ARRAY[$SELECTION]}"
fi

# Job name with timestamp
JOB_NAME="sensitive-data-discovery-$(date +%Y%m%d-%H%M%S)"

echo -e "\n=== Creating Classification Job: $JOB_NAME ==="

# Create a simple classification job for the first available bucket
# This is a simplified version that works without jq
FIRST_BUCKET="${BUCKET_ARRAY[0]}"
if [ "$SELECTION" != "all" ]; then
    FIRST_BUCKET="${BUCKET_ARRAY[$SELECTION]}"
fi

echo -e "${BLUE}Creating job for bucket: $FIRST_BUCKET${NC}"

# Get current account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)
if [ -z "$ACCOUNT_ID" ] || [ "$ACCOUNT_ID" = "None" ]; then
    echo -e "${RED}Failed to retrieve account ID. Check AWS credentials.${NC}"
    exit 1
fi
echo -e "${BLUE}Account ID: $ACCOUNT_ID${NC}"

# Create the classification job using AWS CLI with correct parameter structure
aws macie2 create-classification-job \
    --job-type ONE_TIME \
    --name "$JOB_NAME" \
    --description "Sensitive data discovery job for account ${ACCOUNT_NAME}" \
    --s3-job-definition "{
        \"bucketDefinitions\": [
            {
                \"accountId\": \"$ACCOUNT_ID\",
                \"buckets\": [\"$FIRST_BUCKET\"]
            }
        ]
    }" \
    --region $REGION

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Classification job created successfully!${NC}"
    
    echo -e "\n=== Job Details ==="
    echo "Job Name: $JOB_NAME"
    echo "Job Type: ONE_TIME"
    echo "Selected Bucket: $FIRST_BUCKET"
    
    # List current jobs
    echo -e "\n=== Current Classification Jobs ==="
    aws macie2 list-classification-jobs \
        --region $REGION \
        --query 'items[].{Name: name, Status: jobStatus, CreatedAt: createdAt}' \
        --output table
    
    echo -e "\n${BLUE}Monitor job progress with: ./get-macie-findings.sh${NC}"
    echo -e "${BLUE}Check findings in Security Hub integration${NC}"
    
    if [ "$SELECTION" = "all" ]; then
        echo -e "\n${YELLOW}Note: This simplified version creates a job for the first bucket only.${NC}"
        echo -e "${YELLOW}For multiple buckets, create separate jobs or use the AWS Console.${NC}"
    fi
else
    echo -e "${RED}Failed to create classification job${NC}"
    exit 1
fi
