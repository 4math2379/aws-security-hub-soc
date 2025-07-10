#!/bin/bash

echo "Exporting Security Hub findings to CSV for ${ACCOUNT_NAME:-default}..."

mkdir -p /output/csv

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
CSV_FILE="/output/csv/findings-${ACCOUNT_NAME}-${TIMESTAMP}.csv"

echo "AccountId,Title,Severity,ComplianceStatus,ResourceType,ResourceId,StandardsControl,UpdatedAt" > "$CSV_FILE"

aws securityhub get-findings \
    --max-items 1000 \
    --query 'Findings[].[
        AwsAccountId,
        Title,
        Severity.Label,
        Compliance.Status,
        Resources[0].Type,
        Resources[0].Id,
        ProductFields.StandardsControlArn,
        UpdatedAt
    ]' \
    --output text | while IFS=$'\t' read -r account title severity compliance restype resid control updated; do
    
    title=$(echo "$title" | sed 's/,/ /g' | sed 's/"//g')
    resid=$(echo "$resid" | sed 's/,/ /g')
    
    echo "\"$account\",\"$title\",\"$severity\",\"$compliance\",\"$restype\",\"$resid\",\"$control\",\"$updated\"" >> "$CSV_FILE"
done

TOTAL_FINDINGS=$(wc -l < "$CSV_FILE")
TOTAL_FINDINGS=$((TOTAL_FINDINGS - 1))

echo -e "\n=== Export Summary ==="
echo "Total findings exported: $TOTAL_FINDINGS"
echo "CSV file saved to: $CSV_FILE"

echo -e "\n=== Findings by Severity ==="
tail -n +2 "$CSV_FILE" | cut -d',' -f3 | sort | uniq -c | sed 's/^ *//'

echo -e "\n=== Findings by Compliance Status ==="
tail -n +2 "$CSV_FILE" | cut -d',' -f4 | sort | uniq -c | sed 's/^ *//'

echo -e "\n=== Top 10 Resource Types ==="
tail -n +2 "$CSV_FILE" | cut -d',' -f5 | sort | uniq -c | sort -nr | head -10 | sed 's/^ *//'

echo -e "\nExport completed successfully!"
