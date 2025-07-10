#!/bin/bash

echo "Aggregating Security Hub findings across all member accounts..."

echo -e "\n=== Member Accounts ==="
aws securityhub list-members \
    --query 'Members[].{
        AccountId: AccountId,
        Email: Email,
        Status: MemberStatus
    }' \
    --output table

echo -e "\n=== Aggregated Findings Summary ==="
aws securityhub get-findings \
    --filters '{"AwsAccountId": [{"Comparison": "NOT_EQUALS", "Value": "SELF"}]}' \
    --query 'Findings[].{
        AccountId: AwsAccountId,
        Title: Title,
        Severity: Severity.Label,
        ComplianceStatus: Compliance.Status,
        ResourceType: Resources[0].Type
    }' \
    --output table \
    > /output/aggregated-summary-$(date +%Y%m%d-%H%M%S).txt

echo -e "\n=== Findings Count by Account ==="
aws securityhub get-findings \
    --query 'Findings[].AwsAccountId' \
    --output text | \
    sort | uniq -c | \
    awk '{print "Account:", $2, "- Findings:", $1}'

aws securityhub get-findings \
    --output json \
    > /output/aggregated-findings-$(date +%Y%m%d-%H%M%S).json

echo -e "\nAggregated findings saved to /output/"
