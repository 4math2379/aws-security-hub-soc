#!/bin/bash

echo "Retrieving Amazon Macie Findings for ${ACCOUNT_NAME:-default}..."

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
    
    # Count findings
    FINDING_COUNT=$(jq '.findingIds | length' "$OUTPUT_FILE")
    echo -e "${BLUE}Total findings: $FINDING_COUNT${NC}"
    
    if [ "$FINDING_COUNT" -gt 0 ]; then
        echo -e "\n=== Getting Detailed Findings ==="
        DETAILED_OUTPUT_FILE="/output/macie-findings-detailed-${TIMESTAMP}.json"
        
        # Get detailed findings
        FINDING_IDS=$(jq -r '.findingIds[]' "$OUTPUT_FILE" | head -50 | tr '\n' ' ')
        if [ -n "$FINDING_IDS" ]; then
            aws macie2 get-findings \
                --finding-ids $FINDING_IDS \
                --region $REGION \
                --output json > "$DETAILED_OUTPUT_FILE"
            
            echo -e "${GREEN}Detailed findings exported to: $DETAILED_OUTPUT_FILE${NC}"
            
            # Summary by severity
            echo -e "\n=== Findings Summary by Severity ==="
            jq -r '.findings[] | .severity.description' "$DETAILED_OUTPUT_FILE" | sort | uniq -c | sort -nr
            
            # Summary by type
            echo -e "\n=== Findings Summary by Type ==="
            jq -r '.findings[] | .type' "$DETAILED_OUTPUT_FILE" | sort | uniq -c | sort -nr
            
            # Sample findings
            echo -e "\n=== Sample Findings (High/Medium Severity) ==="
            jq -r '.findings[] | select(.severity.description == "High" or .severity.description == "Medium") | {title: .title, description: .description, severity: .severity.description, resource: .resources[0].resourcesAffected.s3Bucket.name}' "$DETAILED_OUTPUT_FILE" | head -20
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
