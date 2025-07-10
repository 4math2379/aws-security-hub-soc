#!/bin/bash

echo "Enabling AWS Security Hub for ${ACCOUNT_NAME:-default}..."

echo -e "\n=== Checking Security Hub Status ==="
aws securityhub describe-hub --region ${AWS_DEFAULT_REGION} 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Security Hub is not enabled. Enabling now..."
    aws securityhub enable-security-hub \
        --enable-default-standards \
        --region ${AWS_DEFAULT_REGION}
    echo "Security Hub enabled successfully!"
else
    echo "Security Hub is already enabled."
fi

echo -e "\n=== Available Standards ==="
aws securityhub describe-standards \
    --query 'Standards[].{Name: Name, StandardsArn: StandardsArn}' \
    --output table

echo -e "\n=== Enabling Additional Standards ==="
aws securityhub batch-enable-standards \
    --standards-subscription-requests \
        StandardsArn="arn:aws:securityhub:${AWS_DEFAULT_REGION}::standards/aws-foundational-security-best-practices/v/1.0.0" \
        StandardsArn="arn:aws:securityhub:${AWS_DEFAULT_REGION}::standards/cis-aws-foundations-benchmark/v/1.2.0" \
        StandardsArn="arn:aws:securityhub:${AWS_DEFAULT_REGION}::standards/pci-dss/v/3.2.1" \
    2>/dev/null || echo "Some standards may already be enabled"

echo -e "\n=== Currently Enabled Standards ==="
aws securityhub get-enabled-standards \
    --query 'StandardsSubscriptions[].{Name: StandardsArn, Status: StandardsStatus}' \
    --output table

echo -e "\nSecurity Hub setup completed for ${ACCOUNT_NAME}!"
