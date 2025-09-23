#!/bin/bash

# Get Critical Prowler Findings Script
# This script extracts critical and high severity findings from Prowler reports

set -e

# Configuration
ACCOUNT_NAME=${ACCOUNT_NAME:-"default"}
OUTPUT_DIR="/output"
PROWLER_OUTPUT_DIR="$OUTPUT_DIR/prowler"

echo "========================================"
echo "Extracting Critical Prowler Findings"
echo "Account: $ACCOUNT_NAME"
echo "========================================"

# Function to process JSON findings
process_json_findings() {
    local json_file="$1"
    local severity_filter="$2"
    
    if [[ ! -f "$json_file" ]]; then
        echo "JSON file not found: $json_file"
        return 1
    fi
    
    echo "Processing: $(basename "$json_file")"
    
    # Extract findings based on severity using jq if available, otherwise use python
    if command -v jq &> /dev/null; then
        jq -r --arg severity "$severity_filter" '
            .findings[] | 
            select(.status == "FAIL" and (.severity == $severity or $severity == "all")) |
            "\(.check_id) | \(.severity) | \(.check_title) | \(.resource_id // "N/A") | \(.region) | \(.status_extended // .check_title)"
        ' "$json_file"
    else
        # Fallback to Python if jq is not available
        python3 -c "
import json
import sys

with open('$json_file', 'r') as f:
    data = json.load(f)

severity_filter = '$severity_filter'
for finding in data.get('findings', []):
    if finding.get('status') == 'FAIL':
        if severity_filter == 'all' or finding.get('severity', '').lower() == severity_filter.lower():
            print(f\"{finding.get('check_id', 'N/A')} | {finding.get('severity', 'N/A')} | {finding.get('check_title', 'N/A')} | {finding.get('resource_id', 'N/A')} | {finding.get('region', 'N/A')} | {finding.get('status_extended', finding.get('check_title', 'N/A'))}\")
"
    fi
}

# Function to generate summary report
generate_summary() {
    local json_file="$1"
    local output_file="${json_file%.*}_summary.txt"
    
    echo "Generating summary report: $(basename "$output_file")"
    
    {
        echo "========================================"
        echo "Prowler Security Assessment Summary"
        echo "Account: $ACCOUNT_NAME"
        echo "Report Date: $(date)"
        echo "Source: $(basename "$json_file")"
        echo "========================================"
        echo ""
        
        echo "CRITICAL FINDINGS:"
        echo "=================="
        process_json_findings "$json_file" "CRITICAL" | head -20
        echo ""
        
        echo "HIGH SEVERITY FINDINGS:"
        echo "======================"
        process_json_findings "$json_file" "HIGH" | head -20
        echo ""
        
        echo "MEDIUM SEVERITY FINDINGS (Top 10):"
        echo "=================================="
        process_json_findings "$json_file" "MEDIUM" | head -10
        echo ""
        
        # Count findings by severity
        echo "FINDINGS COUNT BY SEVERITY:"
        echo "=========================="
        if command -v jq &> /dev/null; then
            echo -n "CRITICAL: "
            jq -r '.findings[] | select(.status == "FAIL" and .severity == "CRITICAL") | .severity' "$json_file" | wc -l
            echo -n "HIGH: "
            jq -r '.findings[] | select(.status == "FAIL" and .severity == "HIGH") | .severity' "$json_file" | wc -l
            echo -n "MEDIUM: "
            jq -r '.findings[] | select(.status == "FAIL" and .severity == "MEDIUM") | .severity' "$json_file" | wc -l
            echo -n "LOW: "
            jq -r '.findings[] | select(.status == "FAIL" and .severity == "LOW") | .severity' "$json_file" | wc -l
            echo -n "TOTAL FAILED: "
            jq -r '.findings[] | select(.status == "FAIL") | .status' "$json_file" | wc -l
        else
            python3 -c "
import json

with open('$json_file', 'r') as f:
    data = json.load(f)

severities = {'CRITICAL': 0, 'HIGH': 0, 'MEDIUM': 0, 'LOW': 0, 'TOTAL_FAILED': 0}

for finding in data.get('findings', []):
    if finding.get('status') == 'FAIL':
        severities['TOTAL_FAILED'] += 1
        severity = finding.get('severity', '').upper()
        if severity in severities:
            severities[severity] += 1

for sev, count in severities.items():
    if sev == 'TOTAL_FAILED':
        print(f'{sev}: {count}')
    else:
        print(f'{sev}: {count}')
"
        fi
        
    } > "$output_file"
    
    echo "Summary saved to: $(basename "$output_file")"
}

# Function to export findings to CSV
export_to_csv() {
    local json_file="$1"
    local csv_file="${json_file%.*}_critical_findings.csv"
    
    echo "Exporting critical findings to CSV: $(basename "$csv_file")"
    
    {
        echo "CheckId,Severity,Title,ResourceId,Region,Status,Description"
        process_json_findings "$json_file" "all" | while IFS=' | ' read -r check_id severity title resource_id region description; do
            # Only export CRITICAL and HIGH findings
            if [[ "$severity" == "CRITICAL" || "$severity" == "HIGH" ]]; then
                # Escape commas and quotes in CSV
                title=$(echo "$title" | sed 's/,/;/g' | sed 's/"/\\""/g')
                description=$(echo "$description" | sed 's/,/;/g' | sed 's/"/\\""/g')
                echo "$check_id,$severity,$title,$resource_id,$region,FAIL,$description"
            fi
        done
    } > "$csv_file"
    
    echo "CSV export completed: $(basename "$csv_file")"
}

# Main execution
main() {
    local severity_filter=${1:-"CRITICAL"}
    
    # Find latest Prowler JSON reports
    if [[ ! -d "$PROWLER_OUTPUT_DIR/reports" ]]; then
        echo "No Prowler reports directory found. Please run Prowler assessment first."
        echo "Use: ./run-prowler-assessment.sh"
        exit 1
    fi
    
    # Find JSON files
    json_files=$(find "$PROWLER_OUTPUT_DIR/reports" -name "*.json" -type f | sort -r)
    
    if [[ -z "$json_files" ]]; then
        echo "No Prowler JSON reports found in $PROWLER_OUTPUT_DIR/reports"
        echo "Please run Prowler assessment first with: ./run-prowler-assessment.sh"
        exit 1
    fi
    
    echo "Found Prowler reports:"
    echo "$json_files" | while read -r file; do
        echo "- $(basename "$file")"
    done
    echo ""
    
    # Process each JSON file
    for json_file in $json_files; do
        echo "========================================"
        echo "Processing: $(basename "$json_file")"
        echo "========================================"
        
        case "$severity_filter" in
            "CRITICAL"|"critical")
                echo "CRITICAL FINDINGS:"
                process_json_findings "$json_file" "CRITICAL"
                ;;
            "HIGH"|"high")
                echo "HIGH SEVERITY FINDINGS:"
                process_json_findings "$json_file" "HIGH"
                ;;
            "all"|"ALL")
                echo "ALL FAILED FINDINGS:"
                process_json_findings "$json_file" "all"
                ;;
            "summary")
                generate_summary "$json_file"
                ;;
            "csv")
                export_to_csv "$json_file"
                ;;
            *)
                echo "Usage: $0 [CRITICAL|HIGH|all|summary|csv]"
                echo ""
                echo "Options:"
                echo "  CRITICAL - Show only critical findings"
                echo "  HIGH     - Show only high severity findings"
                echo "  all      - Show all failed findings"
                echo "  summary  - Generate detailed summary report"
                echo "  csv      - Export critical/high findings to CSV"
                echo ""
                echo "Default: CRITICAL"
                exit 1
                ;;
        esac
        
        echo ""
    done
    
    echo "========================================"
    echo "Critical findings analysis completed"
    echo "========================================"
}

# Check if any Prowler reports exist
if [[ ! -d "$PROWLER_OUTPUT_DIR" ]]; then
    mkdir -p "$PROWLER_OUTPUT_DIR/reports"
fi

# Run main function
main "$@"
