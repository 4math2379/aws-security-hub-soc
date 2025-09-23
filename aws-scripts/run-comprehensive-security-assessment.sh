#!/bin/bash

# Comprehensive Security Assessment Script
# This script runs both AWS Security Hub findings extraction and Prowler security assessment

set -e

# Configuration
ACCOUNT_NAME=${ACCOUNT_NAME:-"default"}
AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-"us-east-1"}
OUTPUT_DIR="/output"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "=========================================="
echo "COMPREHENSIVE SECURITY ASSESSMENT"
echo "=========================================="
echo "Account: $ACCOUNT_NAME"
echo "Region: $AWS_DEFAULT_REGION"
echo "Timestamp: $TIMESTAMP"
echo "=========================================="

# Function to check if Security Hub is enabled
check_security_hub_status() {
    echo "Checking Security Hub status..."
    if aws securityhub get-enabled-standards --region "$AWS_DEFAULT_REGION" >/dev/null 2>&1; then
        echo "✓ Security Hub is enabled"
        return 0
    else
        echo "✗ Security Hub is not enabled"
        return 1
    fi
}

# Function to run Security Hub assessment
run_security_hub_assessment() {
    echo ""
    echo "=========================================="
    echo "Phase 1: Security Hub Findings Extraction"
    echo "=========================================="
    
    # Run existing Security Hub scripts
    if [[ -f "/aws-scripts/get-findings.sh" ]]; then
        echo "Extracting all Security Hub findings..."
        /aws-scripts/get-findings.sh
    fi
    
    if [[ -f "/aws-scripts/get-critical-findings.sh" ]]; then
        echo "Extracting critical Security Hub findings..."
        /aws-scripts/get-critical-findings.sh
    fi
    
    if [[ -f "/aws-scripts/get-compliance-summary.sh" ]]; then
        echo "Generating compliance summary..."
        /aws-scripts/get-compliance-summary.sh
    fi
    
    echo "Security Hub assessment completed"
}

# Function to run Prowler assessment
run_prowler_assessment() {
    local assessment_type=${1:-"cis"}
    
    echo ""
    echo "=========================================="
    echo "Phase 2: Prowler Security Assessment"
    echo "=========================================="
    
    if [[ -f "/aws-scripts/run-prowler-assessment.sh" ]]; then
        echo "Running Prowler assessment ($assessment_type)..."
        /aws-scripts/run-prowler-assessment.sh "$assessment_type"
    else
        echo "Warning: Prowler assessment script not found"
        return 1
    fi
    
    echo "Prowler assessment completed"
}

# Function to generate combined reports
generate_combined_reports() {
    echo ""
    echo "=========================================="
    echo "Phase 3: Combined Reporting"
    echo "=========================================="
    
    local combined_report="$OUTPUT_DIR/combined-security-assessment-${TIMESTAMP}.txt"
    
    {
        echo "=========================================="
        echo "COMBINED SECURITY ASSESSMENT REPORT"
        echo "=========================================="
        echo "Account: $ACCOUNT_NAME"
        echo "Region: $AWS_DEFAULT_REGION"
        echo "Generated: $(date)"
        echo "Assessment Types: Security Hub + Prowler"
        echo "=========================================="
        echo ""
        
        echo "SECURITY HUB FINDINGS SUMMARY:"
        echo "==============================="
        
        # Find latest Security Hub findings
        latest_findings=$(find "$OUTPUT_DIR" -name "findings-*.json" -type f | sort -r | head -1)
        if [[ -f "$latest_findings" ]]; then
            echo "Source: $(basename "$latest_findings")"
            
            # Count findings by severity using Python
            python3 << EOF
import json
import sys

try:
    with open('$latest_findings', 'r') as f:
        data = json.load(f)
    
    findings = data.get('Findings', [])
    severities = {'CRITICAL': 0, 'HIGH': 0, 'MEDIUM': 0, 'LOW': 0, 'INFORMATIONAL': 0}
    
    for finding in findings:
        severity = finding.get('Severity', {}).get('Label', 'UNKNOWN').upper()
        if severity in severities:
            severities[severity] += 1
    
    print("Security Hub Findings by Severity:")
    for severity, count in severities.items():
        if count > 0:
            print(f"  {severity}: {count}")
    
    print(f"Total Security Hub Findings: {len(findings)}")

except Exception as e:
    print(f"Error processing Security Hub findings: {e}")
EOF
        else
            echo "No Security Hub findings found"
        fi
        
        echo ""
        echo "PROWLER FINDINGS SUMMARY:"
        echo "========================="
        
        # Find latest Prowler JSON report
        latest_prowler=$(find "$OUTPUT_DIR" -path "*/prowler/reports/*.json" -type f | sort -r | head -1)
        if [[ -f "$latest_prowler" ]]; then
            echo "Source: $(basename "$latest_prowler")"
            
            # Extract Prowler summary
            if [[ -f "/aws-scripts/get-prowler-critical-findings.sh" ]]; then
                /aws-scripts/get-prowler-critical-findings.sh summary >/dev/null 2>&1
            fi
            
            # Count Prowler findings
            python3 << EOF
import json
import sys

try:
    with open('$latest_prowler', 'r') as f:
        data = json.load(f)
    
    findings = data.get('findings', [])
    severities = {'CRITICAL': 0, 'HIGH': 0, 'MEDIUM': 0, 'LOW': 0}
    statuses = {'PASS': 0, 'FAIL': 0}
    
    for finding in findings:
        status = finding.get('status', 'UNKNOWN')
        if status in statuses:
            statuses[status] += 1
            
        if status == 'FAIL':
            severity = finding.get('severity', 'UNKNOWN').upper()
            if severity in severities:
                severities[severity] += 1
    
    print("Prowler Check Results:")
    print(f"  PASSED: {statuses.get('PASS', 0)}")
    print(f"  FAILED: {statuses.get('FAIL', 0)}")
    print()
    print("Failed Checks by Severity:")
    for severity, count in severities.items():
        if count > 0:
            print(f"  {severity}: {count}")

except Exception as e:
    print(f"Error processing Prowler findings: {e}")
EOF
        else
            echo "No Prowler findings found"
        fi
        
        echo ""
        echo "COMBINED RISK ASSESSMENT:"
        echo "========================="
        
        # Generate combined risk level based on both sources
        python3 << EOF
import json
import sys

# Initialize counters
sh_critical = sh_high = 0
prowler_critical = prowler_high = 0

# Process Security Hub findings
try:
    with open('$latest_findings', 'r') as f:
        data = json.load(f)
    for finding in data.get('Findings', []):
        severity = finding.get('Severity', {}).get('Label', '').upper()
        if severity == 'CRITICAL':
            sh_critical += 1
        elif severity == 'HIGH':
            sh_high += 1
except:
    pass

# Process Prowler findings
try:
    with open('$latest_prowler', 'r') as f:
        data = json.load(f)
    for finding in data.get('findings', []):
        if finding.get('status') == 'FAIL':
            severity = finding.get('severity', '').upper()
            if severity == 'CRITICAL':
                prowler_critical += 1
            elif severity == 'HIGH':
                prowler_high += 1
except:
    pass

total_critical = sh_critical + prowler_critical
total_high = sh_high + prowler_high

print(f"Combined Critical Issues: {total_critical}")
print(f"Combined High Issues: {total_high}")
print()

if total_critical > 0:
    risk_level = "CRITICAL"
    priority = "🔴 IMMEDIATE ACTION REQUIRED"
elif total_high > 10:
    risk_level = "HIGH"
    priority = "🟠 HIGH PRIORITY"
elif total_high > 0:
    risk_level = "MEDIUM-HIGH"
    priority = "🟡 MEDIUM-HIGH PRIORITY"
else:
    risk_level = "LOW-MEDIUM"
    priority = "🟢 LOW-MEDIUM PRIORITY"

print(f"Overall Risk Level: {risk_level}")
print(f"Priority: {priority}")
EOF
        
        echo ""
        echo "RECOMMENDATIONS:"
        echo "================"
        echo "1. Review all critical findings from both Security Hub and Prowler"
        echo "2. Prioritize remediation based on risk level and compliance requirements"
        echo "3. Use Prowler findings to enhance Security Hub configurations"
        echo "4. Schedule regular assessments for continuous monitoring"
        echo "5. Consider automated remediation for common issues"
        
        echo ""
        echo "REPORT LOCATIONS:"
        echo "================="
        echo "Security Hub Reports:"
        find "$OUTPUT_DIR" -name "findings-*.json" -o -name "*compliance*.json" | sort -r | head -5 | while read -r file; do
            echo "  - $(basename "$file")"
        done
        
        echo ""
        echo "Prowler Reports:"
        find "$OUTPUT_DIR" -path "*/prowler/reports/*" -name "*.json" -o -name "*.csv" -o -name "*.html" | sort -r | head -10 | while read -r file; do
            echo "  - $(basename "$file")"
        done
        
    } > "$combined_report"
    
    echo "Combined assessment report generated: $(basename "$combined_report")"
    echo ""
    echo "=========================================="
    echo "ASSESSMENT SUMMARY PREVIEW:"
    echo "=========================================="
    
    # Display first part of the combined report
    head -50 "$combined_report"
    echo "..."
    echo "[Full report saved to $(basename "$combined_report")]"
}

# Function to run post-assessment cleanup
cleanup_and_organize() {
    echo ""
    echo "=========================================="
    echo "Phase 4: Organizing Output"
    echo "=========================================="
    
    # Create organized directory structure
    mkdir -p "$OUTPUT_DIR/security-hub"
    mkdir -p "$OUTPUT_DIR/prowler"
    mkdir -p "$OUTPUT_DIR/combined-reports"
    
    # Move Security Hub files
    find "$OUTPUT_DIR" -maxdepth 1 -name "findings-*.json" -exec mv {} "$OUTPUT_DIR/security-hub/" \; 2>/dev/null || true
    find "$OUTPUT_DIR" -maxdepth 1 -name "*compliance*.json" -exec mv {} "$OUTPUT_DIR/security-hub/" \; 2>/dev/null || true
    
    # Move combined reports
    find "$OUTPUT_DIR" -maxdepth 1 -name "combined-*.txt" -exec mv {} "$OUTPUT_DIR/combined-reports/" \; 2>/dev/null || true
    
    echo "Output organized into structured directories"
    echo "  - Security Hub reports: $OUTPUT_DIR/security-hub/"
    echo "  - Prowler reports: $OUTPUT_DIR/prowler/"
    echo "  - Combined reports: $OUTPUT_DIR/combined-reports/"
}

# Main execution function
main() {
    local assessment_mode=${1:-"full"}
    local prowler_type=${2:-"cis"}
    
    echo "Assessment Mode: $assessment_mode"
    echo "Prowler Type: $prowler_type"
    echo ""
    
    # Check prerequisites
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "Error: AWS credentials not configured or invalid."
        exit 1
    fi
    
    case "$assessment_mode" in
        "security-hub"|"sh")
            echo "Running Security Hub assessment only..."
            check_security_hub_status && run_security_hub_assessment
            ;;
        "prowler"|"p")
            echo "Running Prowler assessment only..."
            run_prowler_assessment "$prowler_type"
            ;;
        "full"|"both")
            echo "Running comprehensive assessment (Security Hub + Prowler)..."
            
            # Run Security Hub if available
            if check_security_hub_status; then
                run_security_hub_assessment
            else
                echo "Skipping Security Hub assessment (not enabled)"
            fi
            
            # Run Prowler assessment
            run_prowler_assessment "$prowler_type"
            
            # Generate combined reports
            generate_combined_reports
            
            # Organize output
            cleanup_and_organize
            ;;
        *)
            echo "Usage: $0 [full|security-hub|prowler] [prowler-type]"
            echo ""
            echo "Assessment modes:"
            echo "  full        - Run both Security Hub and Prowler assessments (default)"
            echo "  security-hub - Run only Security Hub assessment"
            echo "  prowler     - Run only Prowler assessment"
            echo ""
            echo "Prowler types (when using prowler mode):"
            echo "  cis   - CIS AWS Foundations Benchmark (default)"
            echo "  pci   - PCI-DSS v3.2.1"
            echo "  nist  - NIST 800-53 Rev 5"
            echo "  soc2  - SOC2 Type II"
            echo "  full  - All security checks"
            echo "  all   - All compliance frameworks"
            echo ""
            echo "Examples:"
            echo "  $0                    # Full assessment with CIS"
            echo "  $0 full pci          # Full assessment with PCI-DSS"
            echo "  $0 prowler nist      # Prowler only with NIST"
            echo "  $0 security-hub      # Security Hub only"
            exit 1
            ;;
    esac
    
    echo ""
    echo "=========================================="
    echo "ASSESSMENT COMPLETED SUCCESSFULLY!"
    echo "=========================================="
    echo "Account: $ACCOUNT_NAME"
    echo "Total Duration: $(($(date +%s) - $(date -d "$TIMESTAMP" +%s 2>/dev/null || echo 0))) seconds"
    echo "Output Directory: $OUTPUT_DIR"
    echo "=========================================="
}

# Run main function with all arguments
main "$@"
