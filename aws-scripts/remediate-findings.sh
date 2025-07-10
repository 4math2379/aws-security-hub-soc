#!/bin/bash

echo "Starting remediation process for ${ACCOUNT_NAME:-default}..."

mkdir -p /output/remediation

echo -e "\n=== Finding S3 Buckets Without Encryption ==="
aws securityhub get-findings \
    --filters '{"Title": [{"Value": "*S3*encryption*", "Comparison": "CONTAINS"}]}' \
    --query 'Findings[].Resources[0].Id' \
    --output text | while read bucket_arn; do
    
    BUCKET_NAME=$(echo $bucket_arn | cut -d':' -f6)
    if [ ! -z "$BUCKET_NAME" ]; then
        echo "Enabling encryption for bucket: $BUCKET_NAME"
        aws s3api put-bucket-encryption \
            --bucket "$BUCKET_NAME" \
            --server-side-encryption-configuration '{
                "Rules": [{
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }]
            }' 2>/dev/null && echo "✓ Encryption enabled for $BUCKET_NAME" || echo "✗ Failed to enable encryption for $BUCKET_NAME"
    fi
done

echo -e "\n=== Finding EC2 Instances with Public IPs ==="
aws securityhub get-findings \
    --filters '{"Title": [{"Value": "*public*IP*", "Comparison": "CONTAINS"}]}' \
    --query 'Findings[].{
        ResourceId: Resources[0].Id,
        Title: Title,
        Recommendation: Remediation.Recommendation.Text
    }' \
    --output table > /output/remediation/public-ip-instances-$(date +%Y%m%d-%H%M%S).txt

echo -e "\n=== Finding IAM Users Without MFA ==="
aws securityhub get-findings \
    --filters '{"Title": [{"Value": "*MFA*", "Comparison": "CONTAINS"}]}' \
    --query 'Findings[].{
        ResourceId: Resources[0].Id,
        Title: Title,
        ComplianceStatus: Compliance.Status
    }' \
    --output table > /output/remediation/mfa-report-$(date +%Y%m%d-%H%M%S).txt

echo -e "\n=== Finding Security Groups with Unrestricted Access ==="
aws securityhub get-findings \
    --filters '{"Title": [{"Value": "*0.0.0.0/0*", "Comparison": "CONTAINS"}]}' \
    --query 'Findings[].{
        ResourceId: Resources[0].Id,
        Title: Title,
        Severity: Severity.Label
    }' \
    --output json > /output/remediation/unrestricted-sg-$(date +%Y%m%d-%H%M%S).json

echo -e "\n=== Generating Remediation Summary ==="
cat > /output/remediation/summary-$(date +%Y%m%d-%H%M%S).txt << EOF
Remediation Summary for ${ACCOUNT_NAME}
Generated: $(date)

1. S3 Buckets: Attempted to enable encryption for unencrypted buckets
2. EC2 Instances: Listed instances with public IPs (manual review required)
3. IAM Users: Generated report of users without MFA
4. Security Groups: Identified groups with unrestricted access

Next Steps:
- Review generated reports in /output/remediation/
- Manually remediate findings that require human intervention
- Re-run compliance checks after remediation
EOF

echo -e "\nRemediation process completed. Check /output/remediation/ for reports."
