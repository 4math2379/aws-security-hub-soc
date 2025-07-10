#!/bin/bash

echo "Fetching Security Hub compliance summary for ${ACCOUNT_NAME:-default}..."

echo -e "\n=== Enabled Standards ==="
aws securityhub get-enabled-standards \
    --query 'StandardsSubscriptions[].{
        StandardsArn: StandardsArn,
        StandardsStatus: StandardsStatus
    }' \
    --output table

echo -e "\n=== Compliance Scores ==="
for standard in $(aws securityhub get-enabled-standards --query 'StandardsSubscriptions[].StandardsSubscriptionArn' --output text); do
    echo -e "\nStandard: $standard"
    aws securityhub get-compliance-summary \
        --standard-subscription-arn "$standard" \
        --query 'ComplianceSummary.{
            PassedControls: ComplianceSummaryByConfigRule.CompliantCount,
            FailedControls: ComplianceSummaryByConfigRule.NonCompliantCount,
            Score: ComplianceSummaryByConfigRule.ComplianceScore
        }' \
        --output table
done

aws securityhub describe-standards-controls \
    --standards-subscription-arn $(aws securityhub get-enabled-standards --query 'StandardsSubscriptions[0].StandardsSubscriptionArn' --output text) \
    --output json \
    > /output/compliance-report-$(date +%Y%m%d-%H%M%S).json

echo -e "\nDetailed compliance report saved to /output/compliance-report-$(date +%Y%m%d-%H%M%S).json"
