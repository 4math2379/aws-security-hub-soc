#!/bin/bash

echo "Disabling Amazon Macie for ${ACCOUNT_NAME:-default}..."

REGION=${AWS_DEFAULT_REGION:-us-west-2}

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if Macie is enabled
echo -e "\n=== Checking Amazon Macie Status ==="
STATUS=$(aws macie2 get-macie-session --region $REGION --query 'status' --output text 2>/dev/null)
if [ "$STATUS" != "ENABLED" ]; then
    echo -e "${YELLOW}Amazon Macie is not enabled or already disabled.${NC}"
    echo "Current status: $STATUS"
    exit 0
fi

echo -e "${BLUE}Amazon Macie is currently enabled. Proceeding with cleanup...${NC}"

# Function to handle errors
handle_error() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Warning: $1${NC}"
    else
        echo -e "${GREEN}✓ $1${NC}"
    fi
}

# 1. Cancel running classification jobs
echo -e "\n=== Canceling Running Classification Jobs ==="
RUNNING_JOBS=$(aws macie2 list-classification-jobs \
    --region $REGION \
    --query 'items[?jobStatus==`RUNNING`].jobId' \
    --output text 2>/dev/null)

if [ -n "$RUNNING_JOBS" ] && [ "$RUNNING_JOBS" != "None" ]; then
    echo "Found running jobs. Canceling..."
    for job_id in $RUNNING_JOBS; do
        echo "Canceling job: $job_id"
        aws macie2 cancel-classification-job \
            --job-id "$job_id" \
            --region $REGION 2>/dev/null
        handle_error "Canceled classification job: $job_id"
    done
else
    echo -e "${GREEN}No running classification jobs found.${NC}"
fi

# 2. Wait for jobs to be canceled
echo -e "\n=== Waiting for Jobs to Stop ==="
echo -e "${YELLOW}Waiting for classification jobs to finish canceling...${NC}"
sleep 10

# 3. List all classification jobs for final cleanup
echo -e "\n=== Current Classification Jobs Status ==="
aws macie2 list-classification-jobs \
    --region $REGION \
    --query 'items[].{Name: name, Status: jobStatus, JobId: jobId}' \
    --output table 2>/dev/null || echo -e "${YELLOW}No classification jobs found${NC}"

# 4. Remove custom data identifiers (if any)
echo -e "\n=== Removing Custom Data Identifiers ==="
CUSTOM_IDENTIFIERS=$(aws macie2 list-custom-data-identifiers \
    --region $REGION \
    --query 'items[].id' \
    --output text 2>/dev/null)

if [ -n "$CUSTOM_IDENTIFIERS" ] && [ "$CUSTOM_IDENTIFIERS" != "None" ]; then
    echo "Found custom data identifiers. Removing..."
    for identifier_id in $CUSTOM_IDENTIFIERS; do
        echo "Removing custom data identifier: $identifier_id"
        aws macie2 delete-custom-data-identifier \
            --id "$identifier_id" \
            --region $REGION 2>/dev/null
        handle_error "Removed custom data identifier: $identifier_id"
    done
else
    echo -e "${GREEN}No custom data identifiers found.${NC}"
fi

# 5. Remove findings filters (if any)
echo -e "\n=== Removing Findings Filters ==="
FINDINGS_FILTERS=$(aws macie2 list-findings-filters \
    --region $REGION \
    --query 'findingsFilterListItems[].id' \
    --output text 2>/dev/null)

if [ -n "$FINDINGS_FILTERS" ] && [ "$FINDINGS_FILTERS" != "None" ]; then
    echo "Found findings filters. Removing..."
    for filter_id in $FINDINGS_FILTERS; do
        echo "Removing findings filter: $filter_id"
        aws macie2 delete-findings-filter \
            --id "$filter_id" \
            --region $REGION 2>/dev/null
        handle_error "Removed findings filter: $filter_id"
    done
else
    echo -e "${GREEN}No findings filters found.${NC}"
fi

# 6. Remove allow lists (if any)
echo -e "\n=== Removing Allow Lists ==="
ALLOW_LISTS=$(aws macie2 list-allow-lists \
    --region $REGION \
    --query 'allowLists[].id' \
    --output text 2>/dev/null)

if [ -n "$ALLOW_LISTS" ] && [ "$ALLOW_LISTS" != "None" ]; then
    echo "Found allow lists. Removing..."
    for list_id in $ALLOW_LISTS; do
        echo "Removing allow list: $list_id"
        aws macie2 delete-allow-list \
            --id "$list_id" \
            --region $REGION 2>/dev/null
        handle_error "Removed allow list: $list_id"
    done
else
    echo -e "${GREEN}No allow lists found.${NC}"
fi

# 7. Disable findings publication to Security Hub
echo -e "\n=== Disabling Security Hub Integration ==="
aws macie2 put-findings-publication-configuration \
    --destination-type SecurityHub \
    --region $REGION 2>/dev/null
handle_error "Disabled Security Hub integration"

# 8. Remove member accounts (if this is an administrator account)
echo -e "\n=== Removing Member Accounts ==="
MEMBER_ACCOUNTS=$(aws macie2 list-members \
    --region $REGION \
    --query 'members[].accountId' \
    --output text 2>/dev/null)

if [ -n "$MEMBER_ACCOUNTS" ] && [ "$MEMBER_ACCOUNTS" != "None" ]; then
    echo "Found member accounts. Removing..."
    for account_id in $MEMBER_ACCOUNTS; do
        echo "Removing member account: $account_id"
        aws macie2 delete-member \
            --id "$account_id" \
            --region $REGION 2>/dev/null
        handle_error "Removed member account: $account_id"
    done
else
    echo -e "${GREEN}No member accounts found.${NC}"
fi

# 9. Disassociate from administrator (if this is a member account)
echo -e "\n=== Disassociating from Administrator ==="
aws macie2 disassociate-from-administrator-account \
    --region $REGION 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Disassociated from administrator account${NC}"
else
    echo -e "${YELLOW}No administrator association found or already disassociated${NC}"
fi

# 10. Final cleanup - Disable Macie
echo -e "\n=== Disabling Amazon Macie ==="
aws macie2 disable-macie --region $REGION

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Amazon Macie has been successfully disabled${NC}"
    
    # Verify disable
    echo -e "\n=== Verification ==="
    sleep 5
    NEW_STATUS=$(aws macie2 get-macie-session --region $REGION --query 'status' --output text 2>/dev/null)
    if [ "$NEW_STATUS" = "PAUSED" ] || [ "$NEW_STATUS" = "DISABLED" ] || [ -z "$NEW_STATUS" ]; then
        echo -e "${GREEN}✓ Macie status confirmed as disabled${NC}"
    else
        echo -e "${YELLOW}Macie status: $NEW_STATUS${NC}"
    fi
else
    echo -e "${RED}Failed to disable Amazon Macie${NC}"
    exit 1
fi

# 11. Clean up local output files
echo -e "\n=== Cleaning Up Local Files ==="
if [ -d "/output" ]; then
    MACIE_FILES=$(find /output -name "macie-*" -type f 2>/dev/null)
    if [ -n "$MACIE_FILES" ]; then
        echo "Found Macie output files:"
        echo "$MACIE_FILES"
        echo -e "\n${BLUE}Do you want to remove these files? (y/N):${NC}"
        read -r REMOVE_FILES
        if [ "$REMOVE_FILES" = "y" ] || [ "$REMOVE_FILES" = "Y" ]; then
            rm -f /output/macie-* 2>/dev/null
            handle_error "Removed Macie output files"
        else
            echo -e "${YELLOW}Macie output files preserved${NC}"
        fi
    else
        echo -e "${GREEN}No Macie output files found${NC}"
    fi
fi

echo -e "\n=== Macie Cleanup Summary ==="
echo "Region: $REGION"
echo "Account: ${ACCOUNT_NAME:-default}"
echo "Previous Status: ENABLED"
echo "Current Status: $(aws macie2 get-macie-session --region $REGION --query 'status' --output text 2>/dev/null || echo 'DISABLED')"
echo "Cleanup completed at: $(date)"

echo -e "\n${GREEN}Amazon Macie cleanup completed successfully!${NC}"
echo -e "${BLUE}All classification jobs, custom identifiers, filters, and configurations have been removed.${NC}"
echo -e "${BLUE}To re-enable Macie, run: ./enable-macie.sh${NC}"
