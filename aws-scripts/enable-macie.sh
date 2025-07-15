#!/bin/bash

echo "Enabling Amazon Macie for ${ACCOUNT_NAME:-default}..."

REGION=${AWS_DEFAULT_REGION:-us-west-2}

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "\n=== Checking Amazon Macie Status ==="
STATUS=$(aws macie2 get-macie-session --region $REGION 2>/dev/null | jq -r .status)
if [ "$STATUS" != "ENABLED" ]; then
    echo -e "${YELLOW}Amazon Macie is not enabled. Enabling now...${NC}"
    aws macie2 enable-macie --region $REGION
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Amazon Macie enabled successfully!${NC}"
        
        echo -e "${YELLOW}Waiting for Macie to initialize (this may take 1-2 minutes)...${NC}"
        sleep 30
        
        # Check if Macie is properly initialized
        for i in {1..6}; do
            echo -e "${BLUE}Checking Macie status (attempt $i/6)...${NC}"
            STATUS=$(aws macie2 get-macie-session --region $REGION 2>/dev/null | jq -r .status)
            if [ "$STATUS" = "ENABLED" ]; then
                echo -e "${GREEN}Macie is now fully initialized!${NC}"
                break
            fi
            if [ $i -lt 6 ]; then
                echo -e "${YELLOW}Still initializing... waiting 15 seconds${NC}"
                sleep 15
            else
                echo -e "${RED}Macie initialization taking longer than expected. Please check manually.${NC}"
            fi
        done
    else
        echo -e "${RED}Failed to enable Amazon Macie${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}Amazon Macie is already enabled.${NC}"
fi

echo -e "\n=== Configuring Macie Settings ==="
# Configure Macie to publish findings to Security Hub
aws macie2 put-findings-publication-configuration \
    --destination-type SecurityHub \
    --region $REGION

echo -e "${GREEN}Configured Macie to publish findings to Security Hub${NC}"

# Get current Macie session details
echo -e "\n=== Current Macie Session Details ==="
aws macie2 get-macie-session --region $REGION --output table

echo -e "\n=== Waiting for S3 Bucket Discovery ==="
echo -e "${YELLOW}Macie needs time to discover and catalog S3 buckets (5-15 minutes)...${NC}"
echo -e "${BLUE}Checking bucket discovery progress...${NC}"

# Wait for bucket discovery with progress indicator
for i in {1..10}; do
    BUCKET_COUNT=$(aws macie2 describe-buckets --region $REGION --query 'length(buckets)' --output text 2>/dev/null)
    if [ "$BUCKET_COUNT" != "0" ] && [ "$BUCKET_COUNT" != "None" ]; then
        echo -e "${GREEN}Discovered $BUCKET_COUNT S3 buckets!${NC}"
        break
    fi
    if [ $i -lt 10 ]; then
        echo -e "${YELLOW}Still discovering buckets... waiting 30 seconds (attempt $i/10)${NC}"
        sleep 30
    else
        echo -e "${YELLOW}Bucket discovery taking longer than expected. You can check progress later.${NC}"
    fi
done

echo -e "\n=== S3 Buckets Available for Macie Analysis ==="
aws macie2 describe-buckets --region $REGION --query 'buckets[].bucketName' --output table 2>/dev/null || echo -e "${YELLOW}Bucket discovery still in progress...${NC}"

echo -e "\n=== Available Classification Job Types ==="
echo "1. ONE_TIME - Runs the job only once"
echo "2. SCHEDULED - Runs the job on a daily, weekly, or monthly schedule"

echo -e "\n=== Sensitive Data Discovery Configuration ==="
echo "To perform sensitive data discovery, you can:"
echo "1. Create classification jobs for S3 buckets"
echo "2. Review findings in the Macie console"
echo "3. Monitor findings integration with Security Hub"

echo -e "\n${GREEN}Amazon Macie setup completed for ${ACCOUNT_NAME}!${NC}"
echo -e "${BLUE}Next steps:${NC}"
echo "- Run ./create-macie-classification-job.sh to start sensitive data discovery"
echo "- Run ./get-macie-findings.sh to retrieve findings"
echo "- Check Security Hub for integrated Macie findings"
