#!/bin/bash

# Quick Prowler Scan Script
# A simplified wrapper for running common Prowler security checks

set -e

# Configuration
ACCOUNT_NAME=${ACCOUNT_NAME:-"default"}
AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-"us-east-1"}

echo "=========================================="
echo "Quick Prowler Security Scan"
echo "Account: $ACCOUNT_NAME"
echo "Region: $AWS_DEFAULT_REGION"
echo "=========================================="

# Function to run quick CIS scan
quick_cis_scan() {
    echo "Running quick CIS security scan..."
    /aws-scripts/run-prowler-assessment.sh cis
}

# Function to run critical findings scan
critical_findings_scan() {
    echo "Running scan for critical security findings..."
    python3 /data-processor/mini_prowler.py \
        --region "$AWS_DEFAULT_REGION" \
        --account-name "$ACCOUNT_NAME" \
        --compliance "critical" \
        --output-formats json,csv \
        --output-directory /output/prowler/reports \
        --output-filename "${ACCOUNT_NAME}-critical-$(date +%Y%m%d-%H%M%S)" \
        --severity critical,high \
        --log-level ERROR
}

# Function to run specific service scan (using basic checks for all services)
service_scan() {
    local service=$1
    echo "Running Mini Prowler scan focused on $service service..."
    python3 /data-processor/mini_prowler.py \
        --region "$AWS_DEFAULT_REGION" \
        --account-name "$ACCOUNT_NAME" \
        --compliance "basic" \
        --output-formats json,csv \
        --output-directory /output/prowler/reports \
        --output-filename "${ACCOUNT_NAME}-${service}-$(date +%Y%m%d-%H%M%S)" \
        --log-level WARNING
}

# Function to run basic security check
basic_security_check() {
    echo "Running basic security checks (most common issues)..."
    python3 /data-processor/mini_prowler.py \
        --region "$AWS_DEFAULT_REGION" \
        --account-name "$ACCOUNT_NAME" \
        --compliance "basic" \
        --output-formats json,csv \
        --output-directory /output/prowler/reports \
        --output-filename "${ACCOUNT_NAME}-basic-security-$(date +%Y%m%d-%H%M%S)" \
        --log-level WARNING
}

# Function to display results
show_results() {
    echo ""
    echo "=========================================="
    echo "Scan Results"
    echo "=========================================="
    
    # Find latest report
    latest_report=$(find /output/prowler/reports -name "${ACCOUNT_NAME}*.json" -type f | sort -r | head -1)
    
    if [[ -f "$latest_report" ]]; then
        echo "Latest report: $(basename "$latest_report")"
        echo ""
        
        # Show critical findings summary
        /aws-scripts/get-prowler-critical-findings.sh CRITICAL 2>/dev/null | head -10 || {
            echo "Quick summary of findings:"
            python3 << EOF
import json
try:
    with open('$latest_report', 'r') as f:
        data = json.load(f)
    
    findings = data.get('findings', [])
    failed_critical = [f for f in findings if f.get('status') == 'FAIL' and f.get('severity', '').upper() == 'CRITICAL']
    failed_high = [f for f in findings if f.get('status') == 'FAIL' and f.get('severity', '').upper() == 'HIGH']
    
    print(f"Critical findings: {len(failed_critical)}")
    print(f"High findings: {len(failed_high)}")
    print(f"Total failed checks: {len([f for f in findings if f.get('status') == 'FAIL'])}")
    print(f"Total passed checks: {len([f for f in findings if f.get('status') == 'PASS'])}")
    
    if failed_critical:
        print("\nTop 3 Critical Issues:")
        for i, finding in enumerate(failed_critical[:3]):
            print(f"  {i+1}. {finding.get('check_title', 'N/A')}")
            
except Exception as e:
    print(f"Error reading report: {e}")
EOF
        }
    else
        echo "No reports found"
    fi
    
    echo ""
    echo "All reports location: /output/prowler/reports/"
}

# Main execution
main() {
    local scan_type=${1:-"help"}
    
    case "$scan_type" in
        "cis"|"quick")
            echo "Running quick CIS compliance scan..."
            quick_cis_scan
            show_results
            ;;
        "critical"|"crit")
            echo "Running critical findings scan..."
            critical_findings_scan
            show_results
            ;;
        "basic"|"common")
            echo "Running basic security checks..."
            basic_security_check
            show_results
            ;;
        "iam")
            service_scan "iam"
            show_results
            ;;
        "s3")
            service_scan "s3"
            show_results
            ;;
        "ec2")
            service_scan "ec2"
            show_results
            ;;
        "rds")
            service_scan "rds"
            show_results
            ;;
        "cloudtrail")
            service_scan "cloudtrail"
            show_results
            ;;
        "results"|"show")
            show_results
            ;;
        *)
            echo "Quick Prowler Security Scanner"
            echo ""
            echo "Usage: $0 [scan-type]"
            echo ""
            echo "Available scans:"
            echo "  cis        - Quick CIS compliance scan (default)"
            echo "  critical   - Critical findings only (faster scan)"
            echo "  basic      - Common security issues check"
            echo "  iam        - IAM service security scan"
            echo "  s3         - S3 bucket security scan"
            echo "  ec2        - EC2 instance security scan"
            echo "  rds        - RDS database security scan"
            echo "  cloudtrail - CloudTrail logging scan"
            echo "  results    - Show latest scan results"
            echo ""
            echo "Examples:"
            echo "  $0 cis          # Quick CIS scan"
            echo "  $0 critical     # Critical findings only"
            echo "  $0 s3           # S3 security scan"
            echo "  $0 results      # Show latest results"
            echo ""
            echo "For comprehensive scans, use:"
            echo "  ./run-prowler-assessment.sh [cis|pci|nist|soc2|full|all]"
            exit 1
            ;;
    esac
    
    echo ""
    echo "=========================================="
    echo "Quick scan completed!"
    echo "For detailed analysis, run:"
    echo "  ./get-prowler-critical-findings.sh"
    echo "=========================================="
}

# Check prerequisites
if [[ ! -f "/data-processor/mini_prowler.py" ]]; then
    echo "Error: Mini Prowler not found. Please ensure the data-processor directory is mounted."
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    echo "Error: AWS credentials not configured."
    exit 1
fi

# Ensure output directory exists
mkdir -p /output/prowler/reports

# Run main function
main "$@"
