#!/bin/bash

echo "Listing all Amazon Macie resources for ${ACCOUNT_NAME:-default}..."

REGION=${AWS_DEFAULT_REGION:-us-west-2}

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if Macie is enabled
echo -e "\n=== Amazon Macie Service Status ==="
STATUS=$(aws macie2 get-macie-session --region $REGION --query 'status' --output text 2>/dev/null)
if [ "$STATUS" != "ENABLED" ]; then
    echo -e "${YELLOW}Amazon Macie is not enabled.${NC}"
    echo "Current status: $STATUS"
    exit 0
fi

echo -e "${GREEN}Amazon Macie is ENABLED${NC}"

# 1. Macie Session Details
echo -e "\n=== Macie Session Details ==="
aws macie2 get-macie-session --region $REGION --output table

# 2. Classification Jobs
echo -e "\n=== Classification Jobs ==="
JOB_COUNT=$(aws macie2 list-classification-jobs --region $REGION --query 'length(items)' --output text 2>/dev/null)
if [ "$JOB_COUNT" -gt 0 ]; then
    echo -e "${BLUE}Found $JOB_COUNT classification jobs${NC}"
    aws macie2 list-classification-jobs \
        --region $REGION \
        --query 'items[].{Name: name, Status: jobStatus, Type: jobType, CreatedAt: createdAt, JobId: jobId}' \
        --output table
else
    echo -e "${YELLOW}No classification jobs found${NC}"
fi

# 3. S3 Buckets
echo -e "\n=== S3 Buckets Monitored by Macie ==="
BUCKET_COUNT=$(aws macie2 describe-buckets --region $REGION --query 'length(buckets)' --output text 2>/dev/null)
if [ "$BUCKET_COUNT" -gt 0 ]; then
    echo -e "${BLUE}Found $BUCKET_COUNT S3 buckets${NC}"
    aws macie2 describe-buckets \
        --region $REGION \
        --query 'buckets[].{Name: bucketName, Objects: objectCount, Size: sizeInBytes, Versioning: versioning, Encryption: serverSideEncryption}' \
        --output table
else
    echo -e "${YELLOW}No S3 buckets found or discovery in progress${NC}"
fi

# 4. Custom Data Identifiers
echo -e "\n=== Custom Data Identifiers ==="
CUSTOM_ID_COUNT=$(aws macie2 list-custom-data-identifiers --region $REGION --query 'length(items)' --output text 2>/dev/null)
if [ "$CUSTOM_ID_COUNT" -gt 0 ]; then
    echo -e "${BLUE}Found $CUSTOM_ID_COUNT custom data identifiers${NC}"
    aws macie2 list-custom-data-identifiers \
        --region $REGION \
        --query 'items[].{Name: name, Id: id, CreatedAt: createdAt}' \
        --output table
else
    echo -e "${YELLOW}No custom data identifiers found${NC}"
fi

# 5. Findings Filters
echo -e "\n=== Findings Filters ==="
FILTER_COUNT=$(aws macie2 list-findings-filters --region $REGION --query 'length(findingsFilterListItems)' --output text 2>/dev/null)
if [ "$FILTER_COUNT" -gt 0 ]; then
    echo -e "${BLUE}Found $FILTER_COUNT findings filters${NC}"
    aws macie2 list-findings-filters \
        --region $REGION \
        --query 'findingsFilterListItems[].{Name: name, Id: id, Action: action}' \
        --output table
else
    echo -e "${YELLOW}No findings filters found${NC}"
fi

# 6. Allow Lists
echo -e "\n=== Allow Lists ==="
ALLOW_LIST_COUNT=$(aws macie2 list-allow-lists --region $REGION --query 'length(allowLists)' --output text 2>/dev/null)
if [ "$ALLOW_LIST_COUNT" -gt 0 ]; then
    echo -e "${BLUE}Found $ALLOW_LIST_COUNT allow lists${NC}"
    aws macie2 list-allow-lists \
        --region $REGION \
        --query 'allowLists[].{Name: name, Id: id, CreatedAt: createdAt}' \
        --output table
else
    echo -e "${YELLOW}No allow lists found${NC}"
fi

# 7. Findings Publication Configuration
echo -e "\n=== Findings Publication Configuration ==="
aws macie2 get-findings-publication-configuration --region $REGION --output table 2>/dev/null || echo -e "${YELLOW}No findings publication configuration found${NC}"

# 8. Member Accounts (if administrator account)
echo -e "\n=== Member Accounts ==="
MEMBER_COUNT=$(aws macie2 list-members --region $REGION --query 'length(members)' --output text 2>/dev/null)
if [ "$MEMBER_COUNT" -gt 0 ]; then
    echo -e "${BLUE}Found $MEMBER_COUNT member accounts${NC}"
    aws macie2 list-members \
        --region $REGION \
        --query 'members[].{AccountId: accountId, Email: email, Status: relationshipStatus, InvitedAt: invitedAt}' \
        --output table
else
    echo -e "${YELLOW}No member accounts found${NC}"
fi

# 9. Administrator Account (if member account)
echo -e "\n=== Administrator Account ==="
aws macie2 get-administrator-account --region $REGION --output table 2>/dev/null || echo -e "${YELLOW}No administrator account association found${NC}"

# 10. Invitations
echo -e "\n=== Invitations ==="
INVITATION_COUNT=$(aws macie2 list-invitations --region $REGION --query 'length(invitations)' --output text 2>/dev/null)
if [ "$INVITATION_COUNT" -gt 0 ]; then
    echo -e "${BLUE}Found $INVITATION_COUNT invitations${NC}"
    aws macie2 list-invitations \
        --region $REGION \
        --query 'invitations[].{AccountId: accountId, InvitationId: invitationId, Status: relationshipStatus}' \
        --output table
else
    echo -e "${YELLOW}No invitations found${NC}"
fi

# 11. Recent Findings Summary
echo -e "\n=== Recent Findings Summary ==="
FINDING_COUNT=$(aws macie2 list-findings --region $REGION --query 'length(findingIds)' --output text 2>/dev/null)
if [ "$FINDING_COUNT" -gt 0 ]; then
    echo -e "${BLUE}Found $FINDING_COUNT total findings${NC}"
    
    # Get sample findings
    echo -e "\n=== Sample Finding IDs (First 10) ==="
    aws macie2 list-findings \
        --region $REGION \
        --query 'findingIds[0:10]' \
        --output table
else
    echo -e "${YELLOW}No findings found${NC}"
fi

# 12. Usage Statistics
echo -e "\n=== Usage Statistics ==="
CURRENT_DATE=$(date -u +"%Y-%m-%d")
THIRTY_DAYS_AGO=$(date -u -d '30 days ago' +"%Y-%m-%d" 2>/dev/null || date -u -v-30d +"%Y-%m-%d")

aws macie2 get-usage-statistics \
    --time-range "{\
        \"end\": \"$CURRENT_DATE\",\
        \"start\": \"$THIRTY_DAYS_AGO\"\
    }" \
    --region $REGION \
    --query 'records[].{Date: date, DataScanned: dataScanned, ServiceLimit: serviceLimit}' \
    --output table 2>/dev/null || echo -e "${YELLOW}Usage statistics not available${NC}"

# 13. Summary Report
echo -e "\n=== Resource Summary Report ==="
echo "Region: $REGION"
echo "Account: ${ACCOUNT_NAME:-default}"
echo "Macie Status: $STATUS"
echo "Classification Jobs: $JOB_COUNT"
echo "S3 Buckets: $BUCKET_COUNT"
echo "Custom Data Identifiers: $CUSTOM_ID_COUNT"
echo "Findings Filters: $FILTER_COUNT"
echo "Allow Lists: $ALLOW_LIST_COUNT"
echo "Member Accounts: $MEMBER_COUNT"
echo "Invitations: $INVITATION_COUNT"
echo "Total Findings: $FINDING_COUNT"
echo "Report Generated: $(date)"

echo -e "\n${GREEN}Macie resource listing completed!${NC}"
echo -e "${BLUE}Use ./disable-macie.sh to clean up all resources${NC}"
echo -e "${BLUE}Use ./get-macie-findings.sh to get detailed findings${NC}"
