#!/bin/bash

echo "Fetching Security Hub findings for ${ACCOUNT_NAME:-default}..."

mkdir -p /output

aws securityhub get-findings \
    --output json \
    > /output/findings-$(date +%Y%m%d-%H%M%S).json

echo "Findings saved to /output/findings-$(date +%Y%m%d-%H%M%S).json"

echo -e "\n=== Findings Summary ==="
aws securityhub get-findings \
    --query 'Findings[].{
        Title: Title,
        Severity: Severity.Label,
        ComplianceStatus: Compliance.Status,
        ResourceType: Resources[0].Type,
        ResourceId: Resources[0].Id
    }' \
    --output table
