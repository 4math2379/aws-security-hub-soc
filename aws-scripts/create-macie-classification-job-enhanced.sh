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

# Get current account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)
if [ -z "$ACCOUNT_ID" ] || [ "$ACCOUNT_ID" = "None" ]; then
    echo -e "${RED}Failed to retrieve account ID. Check AWS credentials.${NC}"
    exit 1
fi
echo -e "${BLUE}Account ID: $ACCOUNT_ID${NC}"

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
echo -e "\n${BLUE}Select bucket for classification (enter number, or 'all' for first 5 buckets):${NC}"
read -r SELECTION

# Convert to array for easier handling
BUCKET_ARRAY=($BUCKET_NAMES)
BUCKET_COUNT=${#BUCKET_ARRAY[@]}

# Create temporary JSON file for job definition
TEMP_JSON="/tmp/macie-job-definition-$$.json"

if [ "$SELECTION" = "all" ]; then
    echo -e "${YELLOW}Creating classification job for first 5 buckets...${NC}"
    
    # Create JSON for multiple buckets (limit to 5 for demo)
    cat > "$TEMP_JSON" << EOF
{
    "bucketDefinitions": [
        {
            "accountId": "$ACCOUNT_ID",
            "buckets": [
EOF
    
    # Add first 5 buckets
    for i in $(seq 0 4); do
        if [ $i -lt $BUCKET_COUNT ]; then
            if [ $i -eq 0 ]; then
                echo "                \"${BUCKET_ARRAY[$i]}\"" >> "$TEMP_JSON"
            else
                echo "                ,\"${BUCKET_ARRAY[$i]}\"" >> "$TEMP_JSON"
            fi
        fi
    done
    
    cat >> "$TEMP_JSON" << EOF
            ]
        }
    ]
}
EOF

    SELECTED_BUCKETS="${BUCKET_ARRAY[@]:0:5}"
    
else
    if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -ge "$BUCKET_COUNT" ]; then
        echo -e "${RED}Invalid selection. Please enter a valid number.${NC}"
        exit 1
    fi
    
    SELECTED_BUCKET="${BUCKET_ARRAY[$SELECTION]}"
    
    # Create JSON for single bucket
    cat > "$TEMP_JSON" << EOF
{
    "bucketDefinitions": [
        {
            "accountId": "$ACCOUNT_ID",
            "buckets": ["$SELECTED_BUCKET"]
        }
    ]
}
EOF
    
    SELECTED_BUCKETS="$SELECTED_BUCKET"
fi

# Job name with timestamp
JOB_NAME="sensitive-data-discovery-$(date +%Y%m%d-%H%M%S)"

echo -e "\n=== Creating Classification Job: $JOB_NAME ==="
echo -e "${BLUE}Selected buckets: $SELECTED_BUCKETS${NC}"

# Display the JSON that will be used
echo -e "\n=== Job Definition ==="
cat "$TEMP_JSON"

# Create the classification job using the JSON file
aws macie2 create-classification-job \
    --job-type ONE_TIME \
    --name "$JOB_NAME" \
    --description "Sensitive data discovery job for account ${ACCOUNT_NAME}" \
    --s3-job-definition "file://$TEMP_JSON" \
    --region $REGION

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Classification job created successfully!${NC}"
    
    echo -e "\n=== Job Details ==="
    echo "Job Name: $JOB_NAME"
    echo "Job Type: ONE_TIME"
    echo "Account ID: $ACCOUNT_ID"
    echo "Selected Buckets: $SELECTED_BUCKETS"
    
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
    echo -e "${YELLOW}Check the JSON definition above for issues${NC}"
    exit 1
fi

# Clean up temporary file
rm -f "$TEMP_JSON"
echo -e "\n${GREEN}Classification job creation completed!${NC}"
