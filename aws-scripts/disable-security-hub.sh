#!/bin/bash

# This script deactivates AWS Security Hub and cleans up resources in the specified AWS account.
# It handles cases where Security Hub is not enabled and provides proper error handling.

set -e  # Exit on any error

function check_security_hub_status() {
    echo "Checking Security Hub status..."
    if aws securityhub describe-hub >/dev/null 2>&1; then
        echo "Security Hub is enabled."
        return 0
    else
        echo "Security Hub is not enabled or not accessible."
        return 1
    fi
}

function disable_standards() {
    echo "Disabling Security Hub standards..."
    
    # Get enabled standards
    STANDARDS=$(aws securityhub get-enabled-standards --output text --query 'StandardsSubscriptions[].StandardsSubscriptionArn' 2>/dev/null || echo "")
    
    if [ -n "$STANDARDS" ]; then
        for standard in $STANDARDS; do
            echo "Disabling standard: $standard"
            aws securityhub batch-disable-standards --standards-subscription-arns "$standard" >/dev/null 2>&1 || echo "Failed to disable standard: $standard"
        done
    else
        echo "No enabled standards found."
    fi
}

function cleanup_members() {
    echo "Cleaning up Security Hub member accounts..."
    
    # Get member accounts (without using jq)
    MEMBERS_OUTPUT=$(aws securityhub list-members --only-associated --output text --query 'Members[].AccountId' 2>/dev/null || echo "")
    
    if [ -n "$MEMBERS_OUTPUT" ] && [ "$MEMBERS_OUTPUT" != "None" ]; then
        echo "Found member accounts, disassociating and deleting..."
        for account_id in $MEMBERS_OUTPUT; do
            echo "Disassociating member account: $account_id"
            aws securityhub disassociate-members --account-ids "$account_id" >/dev/null 2>&1 || echo "Failed to disassociate: $account_id"
            
            echo "Deleting member account: $account_id"
            aws securityhub delete-members --account-ids "$account_id" >/dev/null 2>&1 || echo "Failed to delete: $account_id"
        done
    else
        echo "No member accounts found."
    fi
}

function cleanup_insights() {
    echo "Cleaning up Security Hub insights..."
    
    # Get insights (without using jq)
    INSIGHTS=$(aws securityhub get-insights --output text --query 'Insights[].InsightArn' 2>/dev/null || echo "")
    
    if [ -n "$INSIGHTS" ] && [ "$INSIGHTS" != "None" ]; then
        for insight_arn in $INSIGHTS; do
            echo "Deleting insight: $insight_arn"
            aws securityhub delete-insight --insight-arn "$insight_arn" >/dev/null 2>&1 || echo "Failed to delete insight: $insight_arn"
        done
    else
        echo "No insights found."
    fi
}

function cleanup_action_targets() {
    echo "Cleaning up Security Hub action targets..."
    
    # Get action targets (without using jq)
    ACTION_TARGETS=$(aws securityhub describe-action-targets --output text --query 'ActionTargets[].ActionTargetArn' 2>/dev/null || echo "")
    
    if [ -n "$ACTION_TARGETS" ] && [ "$ACTION_TARGETS" != "None" ]; then
        for target_arn in $ACTION_TARGETS; do
            echo "Deleting action target: $target_arn"
            aws securityhub delete-action-target --action-target-arn "$target_arn" >/dev/null 2>&1 || echo "Failed to delete action target: $target_arn"
        done
    else
        echo "No action targets found."
    fi
}

function disable_security_hub() {
    echo "Disabling AWS Security Hub..."
    
    if aws securityhub disable-security-hub >/dev/null 2>&1; then
        echo "Security Hub has been successfully disabled."
    else
        echo "Failed to disable Security Hub or it was already disabled."
    fi
}

function main() {
    echo "=== AWS Security Hub Cleanup Script ==="
    echo "This script will disable Security Hub and clean up all related resources."
    echo ""
    
    # Check if Security Hub is enabled
    if check_security_hub_status; then
        echo "Proceeding with Security Hub cleanup..."
        echo ""
        
        # Disable standards first
        disable_standards
        echo ""
        
        # Clean up member accounts
        cleanup_members
        echo ""
        
        # Clean up insights
        cleanup_insights
        echo ""
        
        # Clean up action targets
        cleanup_action_targets
        echo ""
        
        # Finally disable Security Hub
        disable_security_hub
        echo ""
        
        echo "=== Security Hub cleanup completed ==="
    else
        echo "Security Hub is not enabled. No cleanup required."
    fi
}

# Execute the main function
main
