#!/bin/bash

# This script deactivates AWS Security Hub and cleans up resources in the specified AWS account.

function disable_security_hub() {
    echo "Disabling AWS Security Hub for account..."
    aws securityhub disable-security-hub

    echo "Deleting Security Hub member accounts..."
    ACCOUNT_IDS=$(aws securityhub list-members --only-associated | jq -r '.Members[].AccountId')
    if [ -n "$ACCOUNT_IDS" ]; then
        aws securityhub disassociate-members --account-ids $ACCOUNT_IDS
        aws securityhub delete-members --account-ids $ACCOUNT_IDS
    else
        echo "No member accounts found."
    fi

    echo "Cleaning up findings..."
    aws securityhub delete-insight --insight-arn $(aws securityhub list-insights | jq -r '.Insights[].InsightArn')
    aws securityhub delete-action-target --action-target-arn $(aws securityhub list-action-targets | jq -r '.ActionTargets[].ActionTargetArn')

    echo "AWS Security Hub has been deactivated and resources have been cleaned up."
}

# Execute the function
disable_security_hub
