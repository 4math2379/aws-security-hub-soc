#!/bin/bash

echo "Monitoring Security Hub compliance for ${ACCOUNT_NAME:-default}..."

mkdir -p /output/monitoring

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="/output/monitoring/compliance-${ACCOUNT_NAME}-${TIMESTAMP}.json"

echo -e "\n=== Collecting Compliance Metrics ==="

COMPLIANCE_DATA=$(cat <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "account": "${ACCOUNT_NAME}",
  "region": "${AWS_DEFAULT_REGION}",
  "standards": [],
  "summary": {}
}
EOF
)

for standard_arn in $(aws securityhub get-enabled-standards --query 'StandardsSubscriptions[].StandardsSubscriptionArn' --output text); do
    echo "Processing: $standard_arn"
    
    STANDARD_NAME=$(echo "$standard_arn" | awk -F'/' '{print $(NF-2)}')
    
    COMPLIANCE_SUMMARY=$(aws securityhub get-compliance-summary \
        --standard-subscription-arn "$standard_arn" \
        --query 'ComplianceSummary' \
        --output json 2>/dev/null || echo '{}')
    
    if [ "$COMPLIANCE_SUMMARY" != "{}" ]; then
        COMPLIANCE_DATA=$(echo "$COMPLIANCE_DATA" | jq \
            --arg name "$STANDARD_NAME" \
            --arg arn "$standard_arn" \
            --argjson summary "$COMPLIANCE_SUMMARY" \
            '.standards += [{
                "name": $name,
                "arn": $arn,
                "compliance": $summary
            }]')
    fi
done

TOTAL_PASSED=$(echo "$COMPLIANCE_DATA" | jq '[.standards[].compliance.ComplianceSummaryByConfigRule.CompliantCount // 0] | add')
TOTAL_FAILED=$(echo "$COMPLIANCE_DATA" | jq '[.standards[].compliance.ComplianceSummaryByConfigRule.NonCompliantCount // 0] | add')
TOTAL_CONTROLS=$((TOTAL_PASSED + TOTAL_FAILED))

if [ $TOTAL_CONTROLS -gt 0 ]; then
    COMPLIANCE_SCORE=$(echo "scale=2; $TOTAL_PASSED * 100 / $TOTAL_CONTROLS" | bc)
else
    COMPLIANCE_SCORE=0
fi

COMPLIANCE_DATA=$(echo "$COMPLIANCE_DATA" | jq \
    --arg score "$COMPLIANCE_SCORE" \
    --arg passed "$TOTAL_PASSED" \
    --arg failed "$TOTAL_FAILED" \
    --arg total "$TOTAL_CONTROLS" \
    '.summary = {
        "compliance_score": $score,
        "total_controls": $total,
        "passed_controls": $passed,
        "failed_controls": $failed
    }')

echo "$COMPLIANCE_DATA" | jq '.' > "$REPORT_FILE"

echo -e "\n=== Compliance Dashboard ==="
echo "Account: ${ACCOUNT_NAME}"
echo "Region: ${AWS_DEFAULT_REGION}"
echo "Timestamp: $(date)"
echo "Overall Compliance Score: ${COMPLIANCE_SCORE}%"
echo "Total Controls: $TOTAL_CONTROLS"
echo "Passed Controls: $TOTAL_PASSED"
echo "Failed Controls: $TOTAL_FAILED"

echo -e "\n=== Standards Breakdown ==="
echo "$COMPLIANCE_DATA" | jq -r '.standards[] | "\(.name): \(.compliance.ComplianceSummaryByConfigRule.CompliantCount // 0)/\((.compliance.ComplianceSummaryByConfigRule.CompliantCount // 0) + (.compliance.ComplianceSummaryByConfigRule.NonCompliantCount // 0)) controls passed"'

HISTORY_FILE="/output/monitoring/compliance-history.jsonl"
echo "$COMPLIANCE_DATA" | jq -c '.' >> "$HISTORY_FILE"

echo -e "\nCompliance report saved to: $REPORT_FILE"
echo "History appended to: $HISTORY_FILE"
