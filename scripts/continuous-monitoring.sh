#!/bin/bash

# AWS Security Hub Continuous Monitoring Script
# This script runs continuous monitoring and feeds data to the dashboard

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="/output"
LOG_FILE="$OUTPUT_DIR/monitoring.log"
INTERVAL=${MONITORING_INTERVAL:-300}  # 5 minutes default

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Create output directories
mkdir -p "$OUTPUT_DIR/metrics"
mkdir -p "$OUTPUT_DIR/csv"

log "Starting continuous monitoring for account: ${ACCOUNT_NAME:-default}"

# Function to collect findings
collect_findings() {
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local findings_file="$OUTPUT_DIR/findings-$timestamp.json"
    local csv_file="$OUTPUT_DIR/csv/findings-${ACCOUNT_NAME}-$timestamp.csv"
    
    log "Collecting Security Hub findings..."
    
    # Get findings in JSON format
    if aws securityhub get-findings --output json > "$findings_file" 2>/dev/null; then
        log "Successfully collected findings: $findings_file"
        
        # Generate CSV export
        if [ -f "/aws-scripts/export-findings-csv.sh" ]; then
            /aws-scripts/export-findings-csv.sh
            log "CSV export completed"
        fi
        
        # Generate metrics
        generate_metrics "$findings_file"
        
    else
        log "ERROR: Failed to collect findings"
        return 1
    fi
}

# Function to generate metrics
generate_metrics() {
    local findings_file="$1"
    local metrics_file="$OUTPUT_DIR/metrics/metrics-$(date +%Y%m%d-%H%M%S).json"
    
    log "Generating metrics from $findings_file"
    
    # Extract metrics using jq
    cat "$findings_file" | jq -r '
    {
        "timestamp": now | todate,
        "account": env.ACCOUNT_NAME,
        "total_findings": .Findings | length,
        "by_severity": (.Findings | group_by(.Severity.Label) | map({
            "severity": .[0].Severity.Label,
            "count": length
        })),
        "by_compliance": (.Findings | group_by(.Compliance.Status) | map({
            "status": .[0].Compliance.Status,
            "count": length
        })),
        "by_resource_type": (.Findings | group_by(.Resources[0].Type) | map({
            "type": .[0].Resources[0].Type,
            "count": length
        }) | sort_by(.count) | reverse),
        "critical_count": (.Findings | map(select(.Severity.Label == "CRITICAL")) | length),
        "high_count": (.Findings | map(select(.Severity.Label == "HIGH")) | length),
        "compliance_score": ((.Findings | map(select(.Compliance.Status == "PASSED")) | length) / (.Findings | length) * 100)
    }' > "$metrics_file"
    
    log "Metrics saved to: $metrics_file"
}

# Function to collect compliance summary
collect_compliance() {
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local compliance_file="$OUTPUT_DIR/compliance-$timestamp.json"
    
    log "Collecting compliance summary..."
    
    if [ -f "/aws-scripts/get-compliance-summary.sh" ]; then
        /aws-scripts/get-compliance-summary.sh > "$compliance_file"
        log "Compliance summary saved to: $compliance_file"
    fi
}

# Function to get critical findings
collect_critical_findings() {
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local critical_file="$OUTPUT_DIR/critical-$timestamp.json"
    
    log "Collecting critical findings..."
    
    if [ -f "/aws-scripts/get-critical-findings.sh" ]; then
        /aws-scripts/get-critical-findings.sh > "$critical_file"
        log "Critical findings saved to: $critical_file"
    fi
}

# Function to cleanup old files
cleanup_old_files() {
    log "Cleaning up old files..."
    
    # Keep files for 7 days
    find "$OUTPUT_DIR" -name "*.json" -mtime +7 -delete 2>/dev/null || true
    find "$OUTPUT_DIR/csv" -name "*.csv" -mtime +7 -delete 2>/dev/null || true
    find "$OUTPUT_DIR/metrics" -name "*.json" -mtime +7 -delete 2>/dev/null || true
    
    log "Cleanup completed"
}

# Signal handler for graceful shutdown
shutdown_handler() {
    log "Received shutdown signal, stopping monitoring..."
    exit 0
}

# Set up signal handlers
trap shutdown_handler SIGTERM SIGINT

# Main monitoring loop
main() {
    log "Starting continuous monitoring loop (interval: ${INTERVAL}s)"
    
    while true; do
        log "Starting monitoring cycle..."
        
        # Collect data
        collect_findings
        collect_compliance
        collect_critical_findings
        
        # Cleanup old files every hour
        if [ $(($(date +%M) % 60)) -eq 0 ]; then
            cleanup_old_files
        fi
        
        log "Monitoring cycle completed, sleeping for ${INTERVAL}s"
        sleep "$INTERVAL"
    done
}

# Health check function
health_check() {
    log "Performing health check..."
    
    # Check AWS CLI access
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log "ERROR: AWS CLI not properly configured"
        return 1
    fi
    
    # Check Security Hub access
    if ! aws securityhub describe-hub >/dev/null 2>&1; then
        log "ERROR: Security Hub not accessible"
        return 1
    fi
    
    log "Health check passed"
    return 0
}

# Run based on argument
case "${1:-start}" in
    start)
        health_check && main
        ;;
    health)
        health_check
        ;;
    collect)
        collect_findings
        ;;
    *)
        echo "Usage: $0 {start|health|collect}"
        exit 1
        ;;
esac
