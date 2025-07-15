#!/bin/bash

echo "Checking AWS Regions Configuration for ${ACCOUNT_NAME:-default}..."

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "\n=== Current Configuration ==="
echo "AWS_DEFAULT_REGION (environment): ${AWS_DEFAULT_REGION:-not set}"
echo "AWS CLI default region: $(aws configure get region)"
echo "Account ID: $(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)"

echo -e "\n=== S3 Buckets and Their Regions ==="
BUCKET_NAMES=$(aws s3api list-buckets --query 'Buckets[].Name' --output text)
if [ -z "$BUCKET_NAMES" ]; then
    echo -e "${YELLOW}No S3 buckets found.${NC}"
else
    echo "Bucket Name -> Region"
    echo "------------------------"
    for bucket in $BUCKET_NAMES; do
        BUCKET_REGION=$(aws s3api get-bucket-location --bucket "$bucket" --query 'LocationConstraint' --output text 2>/dev/null)
        if [ "$BUCKET_REGION" = "None" ]; then
            BUCKET_REGION="us-east-1"  # Default region
        fi
        echo "$bucket -> $BUCKET_REGION"
    done
fi

echo -e "\n=== Macie Status by Region ==="
COMMON_REGIONS=("us-east-1" "us-west-2" "eu-west-1" "eu-west-3" "eu-central-1" "ap-southeast-1")

for region in "${COMMON_REGIONS[@]}"; do
    STATUS=$(aws macie2 get-macie-session --region "$region" --query 'status' --output text 2>/dev/null)
    if [ "$STATUS" = "ENABLED" ]; then
        echo -e "${GREEN}✓ $region - Macie ENABLED${NC}"
    elif [ "$STATUS" = "PAUSED" ]; then
        echo -e "${YELLOW}⚠ $region - Macie PAUSED${NC}"
    else
        echo -e "${RED}✗ $region - Macie NOT ENABLED${NC}"
    fi
done

echo -e "\n=== Recommendations ==="
CURRENT_REGION=${AWS_DEFAULT_REGION:-$(aws configure get region)}
echo "Current working region: $CURRENT_REGION"

# Count buckets in current region
BUCKETS_IN_REGION=0
if [ -n "$BUCKET_NAMES" ]; then
    for bucket in $BUCKET_NAMES; do
        BUCKET_REGION=$(aws s3api get-bucket-location --bucket "$bucket" --query 'LocationConstraint' --output text 2>/dev/null)
        if [ "$BUCKET_REGION" = "None" ]; then
            BUCKET_REGION="us-east-1"
        fi
        if [ "$BUCKET_REGION" = "$CURRENT_REGION" ]; then
            ((BUCKETS_IN_REGION++))
        fi
    done
fi

echo "Buckets in $CURRENT_REGION: $BUCKETS_IN_REGION"

if [ $BUCKETS_IN_REGION -eq 0 ]; then
    echo -e "${YELLOW}No buckets found in your current region ($CURRENT_REGION).${NC}"
    echo -e "${BLUE}Consider:${NC}"
    echo "1. Enable Macie in a region where you have buckets"
    echo "2. Or create buckets in $CURRENT_REGION"
    echo "3. Or update your region configuration"
else
    echo -e "${GREEN}You have $BUCKETS_IN_REGION buckets in $CURRENT_REGION.${NC}"
    echo -e "${BLUE}You can create Macie classification jobs for these buckets.${NC}"
fi

echo -e "\n=== Common Commands ==="
echo "To enable Macie in a specific region:"
echo "  aws macie2 enable-macie --region <region-name>"
echo ""
echo "To update your AWS CLI region:"
echo "  aws configure set region <region-name>"
echo ""
echo "To update environment variable:"
echo "  export AWS_DEFAULT_REGION=<region-name>"
