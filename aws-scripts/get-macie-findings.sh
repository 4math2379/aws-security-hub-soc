#!/bin/bash

echo "Retrieving Amazon Macie Findings for ${ACCOUNT_NAME:-default}..."

REGION=${AWS_DEFAULT_REGION:-eu-central-1}

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

echo -e "\n=== Classification Jobs Status ==="
aws macie2 list-classification-jobs \
    --region $REGION \
    --query 'items[].{Name: name, Status: jobStatus, CreatedAt: createdAt, Type: jobType}' \
    --output table

echo -e "\n=== Retrieving Macie Findings ==="
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="/output/macie-findings-${TIMESTAMP}.json"

# Get findings
aws macie2 list-findings \
    --region $REGION \
    --output json > "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Findings exported to: $OUTPUT_FILE${NC}"
    
# Count findings using AWS CLI query
    FINDING_COUNT=$(aws macie2 list-findings --region $REGION --query 'length(findingIds)' --output text)
    echo -e "${BLUE}Total findings: $FINDING_COUNT${NC}"
    
    if [ "$FINDING_COUNT" -gt 0 ]; then
        echo -e "\n=== Finding IDs ==="
        aws macie2 list-findings \
            --region $REGION \
            --query 'findingIds[0:10]' \
            --output table
        
        echo -e "\n=== Sample Findings Details ==="
        # Get first few finding IDs
        FIRST_FINDING_ID=$(aws macie2 list-findings --region $REGION --query 'findingIds[0]' --output text)
        if [ "$FIRST_FINDING_ID" != "None" ] && [ -n "$FIRST_FINDING_ID" ]; then
            echo -e "${BLUE}Getting details for finding: $FIRST_FINDING_ID${NC}"
            aws macie2 get-findings \
                --finding-ids "$FIRST_FINDING_ID" \
                --region $REGION \
                --output table
        fi
    else
        echo -e "${YELLOW}No findings found. This could mean:${NC}"
        echo "1. Classification jobs haven't completed yet"
        echo "2. No sensitive data was found"
        echo "3. Jobs are still running"
    fi
else
    echo -e "${RED}Failed to retrieve findings${NC}"
fi

echo -e "\n=== Recent Job Statistics ==="
aws macie2 list-classification-jobs \
    --region $REGION \
    --query 'items[].{Name: name, Status: jobStatus, Statistics: statistics}' \
    --output table

echo -e "\n=== Security Hub Integration Check ==="
echo -e "${BLUE}Checking if findings are being sent to Security Hub...${NC}"
aws macie2 get-findings-publication-configuration --region $REGION --output table 2>/dev/null || echo -e "${YELLOW}No Security Hub integration configured${NC}"

echo -e "\n=== Next Steps ==="
echo "1. Check Security Hub for integrated Macie findings"
echo "2. Review detailed findings in: $OUTPUT_FILE"
echo "3. Monitor job progress with: ./check-macie-status.sh"
echo "4. Create new classification jobs with: ./create-macie-classification-job.sh"
