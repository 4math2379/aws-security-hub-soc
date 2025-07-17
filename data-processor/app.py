#!/usr/bin/env python3
"""
AWS Security Hub Data Processor
Processes Security Hub findings and exposes metrics to Prometheus
"""

import json
import os
import time
import glob
import csv
from datetime import datetime
from flask import Flask, Response
from prometheus_client import Counter, Gauge, Histogram, generate_latest, CollectorRegistry, CONTENT_TYPE_LATEST
import threading
import schedule
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
registry = CollectorRegistry()

# Prometheus metrics
findings_total = Counter('security_hub_findings_total', 'Total security findings', 
                        ['account', 'severity', 'compliance_status', 'resource_type'], registry=registry)
findings_by_severity = Gauge('security_hub_findings_by_severity', 'Findings by severity level', 
                           ['account', 'severity'], registry=registry)
compliance_score = Gauge('security_hub_compliance_score', 'Compliance score by account', 
                        ['account'], registry=registry)
resource_types = Gauge('security_hub_resource_types', 'Resource types with findings', 
                      ['account', 'resource_type'], registry=registry)
critical_findings = Gauge('security_hub_critical_findings', 'Critical findings count', 
                         ['account'], registry=registry)
high_findings = Gauge('security_hub_high_findings', 'High severity findings count', 
                     ['account'], registry=registry)
processing_time = Histogram('security_hub_processing_seconds', 'Time spent processing findings', 
                           registry=registry)

class SecurityHubProcessor:
    def __init__(self, data_dir='/output'):
        self.data_dir = data_dir
        self.last_processed = {}
        
    def process_csv_files(self):
        """Process CSV files from Security Hub exports"""
        start_time = time.time()
        
        try:
            # Find all CSV files
            csv_pattern = os.path.join(self.data_dir, '*/csv/findings-*.csv')
            csv_files = glob.glob(csv_pattern)
            
            logger.info(f"Found {len(csv_files)} CSV files to process")
            
            for csv_file in csv_files:
                self.process_csv_file(csv_file)
                
            # Process JSON files as well
            json_pattern = os.path.join(self.data_dir, '*/findings-*.json')
            json_files = glob.glob(json_pattern)
            
            logger.info(f"Found {len(json_files)} JSON files to process")
            
            for json_file in json_files:
                self.process_json_file(json_file)
                
        except Exception as e:
            logger.error(f"Error processing files: {e}")
        finally:
            processing_time.observe(time.time() - start_time)
    
    def process_csv_file(self, csv_file):
        """Process individual CSV file"""
        try:
            # Extract account name from path
            account_name = self.extract_account_name(csv_file)
            
            # Check if file was already processed
            file_mtime = os.path.getmtime(csv_file)
            if csv_file in self.last_processed and self.last_processed[csv_file] >= file_mtime:
                return
            
            logger.info(f"Processing CSV file: {csv_file}")
            
            # Reset gauges for this account
            findings_by_severity.clear()
            
            severity_counts = {}
            resource_type_counts = {}
            compliance_counts = {'PASSED': 0, 'FAILED': 0, 'WARNING': 0}
            
            with open(csv_file, 'r', newline='', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                
                for row in reader:
                    account_id = row.get('AccountId', account_name)
                    severity = row.get('Severity', 'UNKNOWN')
                    compliance_status = row.get('ComplianceStatus', 'UNKNOWN')
                    resource_type = row.get('ResourceType', 'UNKNOWN')
                    
                    # Update counters
                    findings_total.labels(
                        account=account_name,
                        severity=severity,
                        compliance_status=compliance_status,
                        resource_type=resource_type
                    ).inc()
                    
                    # Count by severity
                    severity_counts[severity] = severity_counts.get(severity, 0) + 1
                    
                    # Count by resource type
                    resource_type_counts[resource_type] = resource_type_counts.get(resource_type, 0) + 1
                    
                    # Count compliance status
                    if compliance_status in compliance_counts:
                        compliance_counts[compliance_status] += 1
            
            # Update gauges
            for severity, count in severity_counts.items():
                findings_by_severity.labels(account=account_name, severity=severity).set(count)
            
            for resource_type, count in resource_type_counts.items():
                resource_types.labels(account=account_name, resource_type=resource_type).set(count)
            
            # Update specific severity gauges
            critical_findings.labels(account=account_name).set(severity_counts.get('CRITICAL', 0))
            high_findings.labels(account=account_name).set(severity_counts.get('HIGH', 0))
            
            # Calculate compliance score
            total_findings = sum(compliance_counts.values())
            if total_findings > 0:
                score = (compliance_counts['PASSED'] / total_findings) * 100
                compliance_score.labels(account=account_name).set(score)
            
            # Mark as processed
            self.last_processed[csv_file] = file_mtime
            
        except Exception as e:
            logger.error(f"Error processing CSV file {csv_file}: {e}")
    
    def process_json_file(self, json_file):
        """Process individual JSON file"""
        try:
            # Extract account name from path
            account_name = self.extract_account_name(json_file)
            
            # Check if file was already processed
            file_mtime = os.path.getmtime(json_file)
            if json_file in self.last_processed and self.last_processed[json_file] >= file_mtime:
                return
            
            logger.info(f"Processing JSON file: {json_file}")
            
            with open(json_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
                
                findings = data.get('Findings', [])
                
                severity_counts = {}
                resource_type_counts = {}
                compliance_counts = {'PASSED': 0, 'FAILED': 0, 'WARNING': 0}
                
                for finding in findings:
                    account_id = finding.get('AwsAccountId', account_name)
                    severity = finding.get('Severity', {}).get('Label', 'UNKNOWN')
                    compliance_status = finding.get('Compliance', {}).get('Status', 'UNKNOWN')
                    
                    resources = finding.get('Resources', [])
                    resource_type = resources[0].get('Type', 'UNKNOWN') if resources else 'UNKNOWN'
                    
                    # Update counters
                    findings_total.labels(
                        account=account_name,
                        severity=severity,
                        compliance_status=compliance_status,
                        resource_type=resource_type
                    ).inc()
                    
                    # Count by severity
                    severity_counts[severity] = severity_counts.get(severity, 0) + 1
                    
                    # Count by resource type
                    resource_type_counts[resource_type] = resource_type_counts.get(resource_type, 0) + 1
                    
                    # Count compliance status
                    if compliance_status in compliance_counts:
                        compliance_counts[compliance_status] += 1
                
                # Update gauges (similar to CSV processing)
                for severity, count in severity_counts.items():
                    findings_by_severity.labels(account=account_name, severity=severity).set(count)
                
                for resource_type, count in resource_type_counts.items():
                    resource_types.labels(account=account_name, resource_type=resource_type).set(count)
                
                # Update specific severity gauges
                critical_findings.labels(account=account_name).set(severity_counts.get('CRITICAL', 0))
                high_findings.labels(account=account_name).set(severity_counts.get('HIGH', 0))
                
                # Calculate compliance score
                total_findings = sum(compliance_counts.values())
                if total_findings > 0:
                    score = (compliance_counts['PASSED'] / total_findings) * 100
                    compliance_score.labels(account=account_name).set(score)
                
                # Mark as processed
                self.last_processed[json_file] = file_mtime
                
        except Exception as e:
            logger.error(f"Error processing JSON file {json_file}: {e}")
    
    def extract_account_name(self, file_path):
        """Extract account name from file path"""
        parts = file_path.split('/')
        for i, part in enumerate(parts):
            if part == 'output' and i + 1 < len(parts):
                return parts[i + 1]
        return 'unknown'

# Global processor instance
processor = SecurityHubProcessor()

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return Response(generate_latest(registry), mimetype=CONTENT_TYPE_LATEST)

@app.route('/health')
def health():
    """Health check endpoint"""
    return {'status': 'healthy', 'timestamp': datetime.now().isoformat()}

@app.route('/process')
def process_data():
    """Manually trigger data processing"""
    processor.process_csv_files()
    return {'status': 'processed', 'timestamp': datetime.now().isoformat()}

def run_scheduler():
    """Run the scheduler in a separate thread"""
    schedule.every(5).minutes.do(processor.process_csv_files)
    
    while True:
        schedule.run_pending()
        time.sleep(60)

if __name__ == '__main__':
    # Start scheduler thread
    scheduler_thread = threading.Thread(target=run_scheduler, daemon=True)
    scheduler_thread.start()
    
    # Initial processing
    processor.process_csv_files()
    
    # Start Flask app
    app.run(host='0.0.0.0', port=8080, debug=False)
