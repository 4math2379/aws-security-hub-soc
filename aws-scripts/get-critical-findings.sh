#!/bin/bash

echo "Fetching critical and high severity findings for ${ACCOUNT_NAME:-default}..."

mkdir -p /output

echo -e "\n=== Critical Findings ==="
aws securityhub get-findings \
    --filters '{"SeverityLabel": [{"Value": "CRITICAL", "Comparison": "EQUALS"}]}' \
    --query 'Findings[].{
        Title: Title,
        ResourceType: Resources[0].Type,
        ResourceId: Resources[0].Id,
        ComplianceStatus: Compliance.Status,
        UpdatedAt: UpdatedAt
    }' \
    --output table

CRITICAL_COUNT=$(aws securityhub get-findings \
    --filters '{"SeverityLabel": [{"Value": "CRITICAL", "Comparison": "EQUALS"}]}' \
    --query 'length(Findings)' \
    --output text)

echo -e "\n=== High Severity Findings ==="
aws securityhub get-findings \
    --filters '{"SeverityLabel": [{"Value": "HIGH", "Comparison": "EQUALS"}]}' \
    --query 'Findings[].{
        Title: Title,
        ResourceType: Resources[0].Type,
        ResourceId: Resources[0].Id,
        ComplianceStatus: Compliance.Status,
        UpdatedAt: UpdatedAt
    }' \
    --output table

HIGH_COUNT=$(aws securityhub get-findings \
    --filters '{"SeverityLabel": [{"Value": "HIGH", "Comparison": "EQUALS"}]}' \
    --query 'length(Findings)' \
    --output text)

echo -e "\n=== Summary ==="
echo "Critical findings: ${CRITICAL_COUNT:-0}"
echo "High severity findings: ${HIGH_COUNT:-0}"

aws securityhub get-findings \
    --filters '{"SeverityLabel": [
        {"Value": "CRITICAL", "Comparison": "EQUALS"},
        {"Value": "HIGH", "Comparison": "EQUALS"}
    ]}' \
    --output json \
    > /output/critical-high-findings-$(date +%Y%m%d-%H%M%S).json

echo -e "\nCritical and high severity findings saved to /output/"
