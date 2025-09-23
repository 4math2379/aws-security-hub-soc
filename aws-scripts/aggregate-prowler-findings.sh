#!/bin/bash

# Aggregate Prowler Findings Script
# This script combines Prowler findings from multiple accounts and generates consolidated reports

set -e

# Configuration
OUTPUT_DIR="/output"
PROWLER_OUTPUT_DIR="$OUTPUT_DIR/prowler"
AGGREGATED_DIR="$PROWLER_OUTPUT_DIR/aggregated"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "========================================"
echo "Aggregating Prowler Findings"
echo "Timestamp: $TIMESTAMP"
echo "========================================"

# Create aggregated output directory
mkdir -p "$AGGREGATED_DIR"

# Function to find all Prowler JSON reports
find_prowler_reports() {
    find "$OUTPUT_DIR" -name "*prowler*.json" -type f 2>/dev/null || true
    find "$OUTPUT_DIR" -path "*/prowler/reports/*.json" -type f 2>/dev/null || true
}

# Function to extract account name from file path or filename
extract_account_name() {
    local file_path="$1"
    local filename=$(basename "$file_path")
    
    # Try to extract account name from filename pattern: account-framework-timestamp.json
    if [[ "$filename" =~ ^([^-]+)-[^-]+-[0-9]+ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        # Try to extract from path: /output/account/prowler/...
        echo "$file_path" | sed -n 's|.*/output/\([^/]*\)/.*|\1|p'
    fi
}

# Function to aggregate findings by severity
aggregate_by_severity() {
    local output_file="$AGGREGATED_DIR/aggregated-findings-by-severity-${TIMESTAMP}.json"
    
    echo "Aggregating findings by severity..."
    
    # Initialize JSON structure
    cat > "$output_file" << 'EOF'
{
    "aggregated_at": "TIMESTAMP_PLACEHOLDER",
    "total_accounts": 0,
    "accounts": [],
    "summary_by_severity": {
        "CRITICAL": 0,
        "HIGH": 0,
        "MEDIUM": 0,
        "LOW": 0,
        "INFORMATIONAL": 0
    },
    "findings_by_account": {}
}
EOF
    
    # Update timestamp
    sed -i "s/TIMESTAMP_PLACEHOLDER/$(date -Iseconds)/" "$output_file"
    
    local account_count=0
    local temp_findings="$AGGREGATED_DIR/temp_findings_${TIMESTAMP}.json"
    
    # Process each Prowler report
    while IFS= read -r json_file; do
        if [[ -f "$json_file" ]]; then
            local account_name=$(extract_account_name "$json_file")
            [[ -z "$account_name" ]] && account_name="unknown-$(basename "$(dirname "$json_file")")"
            
            echo "Processing account: $account_name ($(basename "$json_file"))"
            ((account_count++))
            
            # Extract findings using Python for better JSON handling
            python3 << EOF
import json
import sys

try:
    # Load main aggregation file
    with open('$output_file', 'r') as f:
        main_data = json.load(f)
    
    # Load account findings
    with open('$json_file', 'r') as f:
        account_data = json.load(f)
    
    account_name = '$account_name'
    account_findings = account_data.get('findings', [])
    
    # Update account list
    if account_name not in main_data['accounts']:
        main_data['accounts'].append(account_name)
    
    # Initialize account findings if not exists
    if account_name not in main_data['findings_by_account']:
        main_data['findings_by_account'][account_name] = {
            'CRITICAL': 0,
            'HIGH': 0,
            'MEDIUM': 0,
            'LOW': 0,
            'INFORMATIONAL': 0,
            'total_failed': 0,
            'total_passed': 0,
            'source_file': '$(basename "$json_file")'
        }
    
    # Count findings by severity
    for finding in account_findings:
        status = finding.get('status', 'UNKNOWN')
        severity = finding.get('severity', 'UNKNOWN').upper()
        
        if status == 'FAIL':
            main_data['findings_by_account'][account_name]['total_failed'] += 1
            if severity in main_data['summary_by_severity']:
                main_data['summary_by_severity'][severity] += 1
                main_data['findings_by_account'][account_name][severity] += 1
        elif status == 'PASS':
            main_data['findings_by_account'][account_name]['total_passed'] += 1
    
    # Update total accounts
    main_data['total_accounts'] = len(main_data['accounts'])
    
    # Save updated data
    with open('$output_file', 'w') as f:
        json.dump(main_data, f, indent=2)
        
    print(f"Processed {len(account_findings)} findings for {account_name}")

except Exception as e:
    print(f"Error processing $json_file: {e}", file=sys.stderr)
    sys.exit(1)
EOF
        fi
    done < <(find_prowler_reports)
    
    echo "Aggregation by severity completed: $(basename "$output_file")"
    echo "Total accounts processed: $account_count"
}

# Function to generate consolidated CSV report
generate_consolidated_csv() {
    local csv_file="$AGGREGATED_DIR/consolidated-critical-findings-${TIMESTAMP}.csv"
    
    echo "Generating consolidated CSV report..."
    
    # CSV header
    echo "Account,CheckId,Severity,Title,ResourceId,Region,Status,Framework,Description" > "$csv_file"
    
    # Process each JSON report
    while IFS= read -r json_file; do
        if [[ -f "$json_file" ]]; then
            local account_name=$(extract_account_name "$json_file")
            [[ -z "$account_name" ]] && account_name="unknown"
            
            # Extract critical and high findings
            python3 << EOF
import json
import csv
import sys

try:
    with open('$json_file', 'r') as f:
        data = json.load(f)
    
    account_name = '$account_name'
    findings = data.get('findings', [])
    
    # Process only CRITICAL and HIGH findings
    for finding in findings:
        if finding.get('status') == 'FAIL':
            severity = finding.get('severity', '').upper()
            if severity in ['CRITICAL', 'HIGH']:
                # Escape and clean data for CSV
                check_id = finding.get('check_id', 'N/A').replace(',', ';')
                title = finding.get('check_title', 'N/A').replace(',', ';').replace('"', '""')
                resource_id = finding.get('resource_id', 'N/A').replace(',', ';')
                region = finding.get('region', 'N/A')
                status = finding.get('status', 'N/A')
                framework = finding.get('compliance_framework', 'General').replace(',', ';')
                description = finding.get('status_extended', finding.get('check_title', 'N/A')).replace(',', ';').replace('"', '""')[:200]  # Limit description length
                
                # Append to CSV file
                with open('$csv_file', 'a') as csvfile:
                    csvfile.write(f'"{account_name}","{check_id}","{severity}","{title}","{resource_id}","{region}","{status}","{framework}","{description}"\n')

except Exception as e:
    print(f"Error processing $json_file for CSV: {e}", file=sys.stderr)
EOF
        fi
    done < <(find_prowler_reports)
    
    echo "Consolidated CSV report completed: $(basename "$csv_file")"
}

# Function to generate executive summary
generate_executive_summary() {
    local summary_file="$AGGREGATED_DIR/executive-summary-${TIMESTAMP}.txt"
    local json_aggregate="$AGGREGATED_DIR/aggregated-findings-by-severity-${TIMESTAMP}.json"
    
    if [[ ! -f "$json_aggregate" ]]; then
        echo "Warning: Aggregated JSON file not found. Run aggregation first."
        return 1
    fi
    
    echo "Generating executive summary..."
    
    python3 << EOF > "$summary_file"
import json
from datetime import datetime

try:
    with open('$json_aggregate', 'r') as f:
        data = json.load(f)
    
    print("="*60)
    print("PROWLER SECURITY ASSESSMENT - EXECUTIVE SUMMARY")
    print("="*60)
    print(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Assessment Period: Multi-Account Security Scan")
    print(f"Total Accounts Assessed: {data['total_accounts']}")
    print(f"Accounts: {', '.join(data['accounts'])}")
    print()
    
    print("OVERALL RISK ASSESSMENT:")
    print("-" * 25)
    total_critical = data['summary_by_severity']['CRITICAL']
    total_high = data['summary_by_severity']['HIGH']
    total_medium = data['summary_by_severity']['MEDIUM']
    
    if total_critical > 0:
        risk_level = "CRITICAL"
        risk_color = "🔴"
    elif total_high > 10:
        risk_level = "HIGH"
        risk_color = "🟠"
    elif total_high > 0 or total_medium > 20:
        risk_level = "MEDIUM"
        risk_color = "🟡"
    else:
        risk_level = "LOW"
        risk_color = "🟢"
    
    print(f"Overall Risk Level: {risk_color} {risk_level}")
    print()
    
    print("FINDINGS SUMMARY:")
    print("-" * 17)
    for severity, count in data['summary_by_severity'].items():
        if count > 0:
            print(f"{severity:>12}: {count:>4} findings")
    print()
    
    print("ACCOUNT BREAKDOWN:")
    print("-" * 18)
    for account, findings in data['findings_by_account'].items():
        total_issues = findings['CRITICAL'] + findings['HIGH'] + findings['MEDIUM']
        print(f"\n{account}:")
        print(f"  Critical: {findings['CRITICAL']:>3}")
        print(f"  High:     {findings['HIGH']:>3}")
        print(f"  Medium:   {findings['MEDIUM']:>3}")
        print(f"  Total Failed: {findings['total_failed']:>3}")
        print(f"  Total Passed: {findings['total_passed']:>3}")
    
    print("\n" + "="*60)
    print("PRIORITY RECOMMENDATIONS:")
    print("="*60)
    
    if total_critical > 0:
        print(f"🔴 IMMEDIATE ACTION REQUIRED: {total_critical} critical findings detected")
        print("   - Review all critical findings immediately")
        print("   - Implement emergency remediation procedures")
    
    if total_high > 0:
        print(f"🟠 HIGH PRIORITY: {total_high} high-severity findings require attention")
        print("   - Schedule remediation within 48-72 hours")
        print("   - Review access controls and configurations")
    
    if total_medium > 0:
        print(f"🟡 MEDIUM PRIORITY: {total_medium} medium-severity findings")
        print("   - Plan remediation within next maintenance window")
        print("   - Consider security hardening measures")
    
    print("\n" + "="*60)
    print("NEXT STEPS:")
    print("="*60)
    print("1. Review detailed findings in JSON/CSV reports")
    print("2. Prioritize remediation based on risk level")
    print("3. Schedule follow-up assessments")
    print("4. Update security policies and procedures")
    print("5. Consider automated remediation for common issues")

except Exception as e:
    print(f"Error generating executive summary: {e}")
EOF
    
    echo "Executive summary completed: $(basename "$summary_file")"
    
    # Display summary on console as well
    echo ""
    echo "========================================"
    echo "EXECUTIVE SUMMARY PREVIEW:"
    echo "========================================"
    head -50 "$summary_file"
    echo "..."
    echo "[Full summary saved to $(basename "$summary_file")]"
}

# Main execution
main() {
    local operation=${1:-"all"}
    
    # Check if any Prowler reports exist
    if [[ -z "$(find_prowler_reports)" ]]; then
        echo "No Prowler reports found in any account directories."
        echo "Expected locations:"
        echo "  - /output/*/prowler/reports/*.json"
        echo "  - /output/*prowler*.json"
        echo ""
        echo "Please run Prowler assessments first using: ./run-prowler-assessment.sh"
        exit 1
    fi
    
    echo "Found Prowler reports:"
    find_prowler_reports | while read -r file; do
        echo "- $file"
    done
    echo ""
    
    case "$operation" in
        "severity"|"sev")
            aggregate_by_severity
            ;;
        "csv")
            generate_consolidated_csv
            ;;
        "summary"|"exec")
            aggregate_by_severity  # Need aggregation first
            generate_executive_summary
            ;;
        "all")
            echo "Running complete aggregation process..."
            aggregate_by_severity
            generate_consolidated_csv
            generate_executive_summary
            ;;
        *)
            echo "Usage: $0 [severity|csv|summary|all]"
            echo ""
            echo "Operations:"
            echo "  severity - Aggregate findings by severity level"
            echo "  csv      - Generate consolidated CSV report"
            echo "  summary  - Generate executive summary report"
            echo "  all      - Run all aggregation operations (default)"
            echo ""
            exit 1
            ;;
    esac
    
    echo ""
    echo "========================================"
    echo "Aggregation completed successfully!"
    echo "========================================"
    echo "Output directory: $AGGREGATED_DIR"
    echo "Generated files:"
    find "$AGGREGATED_DIR" -name "*${TIMESTAMP}*" -type f | while read -r file; do
        echo "  - $(basename "$file")"
    done
}

# Run main function
main "$@"
