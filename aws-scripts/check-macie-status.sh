#!/bin/bash

echo "Checking Amazon Macie Status for ${ACCOUNT_NAME:-default}..."

REGION=${AWS_DEFAULT_REGION:-us-west-2}

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "\n=== Amazon Macie Service Status ==="
STATUS=$(aws macie2 get-macie-session --region $REGION 2>/dev/null | jq -r .status)
if [ "$STATUS" = "ENABLED" ]; then
    echo -e "${GREEN}✓ Amazon Macie is ENABLED${NC}"
    
    # Get session details
    echo -e "\n=== Macie Session Details ==="
    aws macie2 get-macie-session --region $REGION --output table
    
    # Check bucket discovery status
    echo -e "\n=== S3 Bucket Discovery Status ==="
    BUCKET_COUNT=$(aws macie2 describe-buckets --region $REGION --query 'length(buckets)' --output text 2>/dev/null)
    if [ "$BUCKET_COUNT" != "0" ] && [ "$BUCKET_COUNT" != "None" ]; then
        echo -e "${GREEN}✓ Discovered $BUCKET_COUNT S3 buckets${NC}"
        
        echo -e "\n=== Available Buckets for Classification ==="
        aws macie2 describe-buckets --region $REGION --query 'buckets[].{Name: bucketName, Objects: objectCount, Size: sizeInBytes}' --output table
    else
        echo -e "${YELLOW}⚠ Bucket discovery still in progress...${NC}"
        echo -e "${BLUE}This can take 5-15 minutes after enabling Macie${NC}"
    fi
    
    # Check current classification jobs
    echo -e "\n=== Current Classification Jobs ==="
    JOB_COUNT=$(aws macie2 list-classification-jobs --region $REGION --query 'length(items)' --output text 2>/dev/null)
    if [ "$JOB_COUNT" != "0" ] && [ "$JOB_COUNT" != "None" ]; then
        echo -e "${GREEN}Found $JOB_COUNT classification jobs${NC}"
        aws macie2 list-classification-jobs \
            --region $REGION \
            --query 'items[].{Name: name, Status: jobStatus, CreatedAt: createdAt, Type: jobType}' \
            --output table
    else
        echo -e "${YELLOW}No classification jobs found${NC}"
        echo -e "${BLUE}Run ./create-macie-classification-job.sh to create one${NC}"
    fi
    
    # Check findings publication configuration
    echo -e "\n=== Findings Publication Configuration ==="
    aws macie2 get-findings-publication-configuration --region $REGION --output table 2>/dev/null || echo -e "${YELLOW}No findings publication configuration found${NC}"
    
    # Check if ready for classification jobs
    echo -e "\n=== Readiness Assessment ==="
    if [ "$BUCKET_COUNT" != "0" ] && [ "$BUCKET_COUNT" != "None" ]; then
        echo -e "${GREEN}✓ Ready to create classification jobs${NC}"
        echo -e "${BLUE}Next step: Run ./create-macie-classification-job.sh${NC}"
    else
        echo -e "${YELLOW}⚠ Wait for bucket discovery to complete before creating classification jobs${NC}"
        echo -e "${BLUE}Check again in 5-10 minutes${NC}"
    fi
    
elif [ "$STATUS" = "PAUSED" ]; then
    echo -e "${YELLOW}⚠ Amazon Macie is PAUSED${NC}"
    echo -e "${BLUE}Run: aws macie2 enable-macie --region $REGION${NC}"
else
    echo -e "${RED}✗ Amazon Macie is NOT ENABLED${NC}"
    echo -e "${BLUE}Run ./enable-macie.sh to enable it${NC}"
fi

echo -e "\n=== Macie Status Summary ==="
echo "Region: $REGION"
echo "Account: ${ACCOUNT_NAME:-default}"
echo "Status: $STATUS"
echo "Timestamp: $(date)"
