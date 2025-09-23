# Prowler Integration with AWS Security Hub SOC

## Overview

This document describes the integration of Prowler CLI with the AWS Security Hub SOC project. Prowler is a comprehensive open-source security assessment tool that performs automated security audits against multiple compliance frameworks including CIS, NIST, PCI-DSS, and SOC2.

## What is Prowler?

Prowler is a security assessment tool that:
- Performs 400+ security checks across 30+ AWS services
- Supports multiple compliance frameworks (CIS, NIST 800-53, PCI-DSS, SOC2, etc.)
- Generates detailed reports in JSON, CSV, and HTML formats
- Can integrate with AWS Security Hub for centralized findings management
- Provides actionable remediation guidance

## Architecture Integration

### Container Setup

Prowler CLI is integrated into the existing multi-stage Docker build:

```dockerfile
# Install Prowler CLI in builder stage
RUN pip3 install --target=/app/python-deps prowler

# Additional Python dependencies for Prowler
RUN pip3 install --target=/app/python-deps \
    botocore \
    rich \
    colorama \
    tabulate
```

### Volume Configuration

Each account container has dedicated output volumes:
- `./output/[account-name]:/output` - Account-specific output directory
- `/output/prowler/reports/` - Prowler reports subdirectory
- `/output/prowler/aggregated/` - Cross-account aggregated reports

## Available Scripts

### 1. Core Prowler Scripts

#### `run-prowler-assessment.sh`
Comprehensive Prowler security assessment script.

**Usage:**
```bash
./run-prowler-assessment.sh [cis|pci|nist|soc2|full|all]
```

**Examples:**
```bash
# CIS AWS Foundations Benchmark
./run-prowler-assessment.sh cis

# PCI-DSS v3.2.1 compliance
./run-prowler-assessment.sh pci

# All compliance frameworks
./run-prowler-assessment.sh all

# Comprehensive security scan (all checks)
./run-prowler-assessment.sh full
```

**Output:** JSON, CSV, and HTML reports in `/output/prowler/reports/`

#### `get-prowler-critical-findings.sh`
Extract and analyze critical findings from Prowler reports.

**Usage:**
```bash
./get-prowler-critical-findings.sh [CRITICAL|HIGH|all|summary|csv]
```

**Examples:**
```bash
# Show only critical findings
./get-prowler-critical-findings.sh CRITICAL

# Generate summary report
./get-prowler-critical-findings.sh summary

# Export to CSV
./get-prowler-critical-findings.sh csv
```

#### `aggregate-prowler-findings.sh`
Aggregate Prowler findings across multiple accounts.

**Usage:**
```bash
./aggregate-prowler-findings.sh [severity|csv|summary|all]
```

**Features:**
- Cross-account findings aggregation
- Executive summary generation
- Risk level assessment
- Consolidated CSV reports

### 2. Wrapper Scripts

#### `run-comprehensive-security-assessment.sh`
Unified script that runs both Security Hub and Prowler assessments.

**Usage:**
```bash
./run-comprehensive-security-assessment.sh [full|security-hub|prowler] [prowler-type]
```

**Examples:**
```bash
# Full assessment (Security Hub + Prowler CIS)
./run-comprehensive-security-assessment.sh full

# Full assessment with PCI-DSS
./run-comprehensive-security-assessment.sh full pci

# Prowler only with NIST
./run-comprehensive-security-assessment.sh prowler nist
```

#### `quick-prowler-scan.sh`
Fast security scans for common issues.

**Usage:**
```bash
./quick-prowler-scan.sh [scan-type]
```

**Available scans:**
- `cis` - Quick CIS compliance scan
- `critical` - Critical findings only
- `basic` - Common security issues
- `iam` - IAM service scan
- `s3` - S3 bucket scan
- `ec2` - EC2 instance scan

## Getting Started

### 1. Build Updated Container

```bash
# Rebuild the container with Prowler
docker-compose build

# Or use the optimized build script
./scripts/build-optimized.sh
```

### 2. Start Containers

```bash
# Start all account containers
docker-compose up -d

# Or start minimal setup
docker-compose -f docker-compose-minimal.yml up -d
```

### 3. Run Your First Prowler Assessment

```bash
# Connect to account container
docker exec -it latecoere-aero bash

# Run CIS compliance assessment
./run-prowler-assessment.sh cis

# Or run quick scan for critical issues
./quick-prowler-scan.sh critical
```

### 4. View Results

```bash
# Show critical findings
./get-prowler-critical-findings.sh CRITICAL

# Generate summary report
./get-prowler-critical-findings.sh summary

# View all reports
ls -la /output/prowler/reports/
```

## Report Formats

### JSON Format
Structured data for programmatic analysis:
```json
{
  "findings": [
    {
      "check_id": "iam_user_console_access_unused",
      "check_title": "Ensure unused users are removed",
      "status": "FAIL",
      "severity": "HIGH",
      "resource_id": "arn:aws:iam::123456789012:user/unused-user",
      "region": "us-east-1",
      "compliance_framework": "CIS-1.4"
    }
  ]
}
```

### CSV Format
Tabular data for spreadsheet analysis:
```csv
CheckId,Severity,Title,ResourceId,Region,Status,Description
iam_user_console_access_unused,HIGH,Ensure unused users are removed,arn:aws:iam::123456789012:user/unused-user,us-east-1,FAIL,User has not logged in for 90+ days
```

### HTML Format
Visual reports with charts and filtering capabilities.

## Integration with Security Hub

### Findings Comparison
The comprehensive assessment script compares findings from both sources:

| Source | Strengths | Use Case |
|--------|-----------|----------|
| Security Hub | AWS native, real-time monitoring | Continuous compliance monitoring |
| Prowler | 400+ checks, multiple frameworks | Comprehensive security audits |

### Combined Risk Assessment
Risk levels are calculated based on findings from both tools:
- **CRITICAL**: Any critical findings from either source
- **HIGH**: 10+ high findings combined
- **MEDIUM-HIGH**: 1-10 high findings
- **LOW-MEDIUM**: Only medium/low findings

## Multi-Account Management

### Account-Specific Scans
Each container runs isolated scans for its assigned account:

```bash
# Account 1 (latecoere-aero)
docker exec -it latecoere-aero ./run-prowler-assessment.sh cis

# Account 2
docker exec -it aws-security-hub-account2 ./run-prowler-assessment.sh pci

# Account 3
docker exec -it aws-security-hub-account3 ./run-prowler-assessment.sh nist
```

### Cross-Account Aggregation
Use the aggregator container for consolidated reporting:

```bash
# Connect to aggregator
docker exec -it aws-security-hub-aggregator bash

# Aggregate all findings
./aggregate-prowler-findings.sh all
```

## Compliance Frameworks

### Supported Frameworks

| Framework | Description | Use Case |
|-----------|-------------|----------|
| CIS 1.4 | Center for Internet Security AWS Foundations | General security baseline |
| PCI-DSS 3.2.1 | Payment Card Industry Data Security | Payment processing environments |
| NIST 800-53 Rev 5 | National Institute of Standards | Government/federal compliance |
| SOC2 Type II | Service Organization Control | Service provider assessments |

### Framework Selection Guide

**For SysOps Teams:**
- Start with CIS for general security posture
- Add PCI-DSS if handling payment data
- Use comprehensive scans for detailed analysis

**For Audit Teams:**
- Use framework-specific scans for compliance reports
- Generate executive summaries for management
- Export CSV reports for audit documentation

**For Security Teams:**
- Run critical/high severity scans for immediate issues
- Use service-specific scans for targeted assessment
- Combine with Security Hub for comprehensive coverage

## Performance Considerations

### Scan Duration
- **Quick scans** (critical only): 2-5 minutes
- **Service-specific scans**: 5-10 minutes  
- **Full compliance scans**: 15-30 minutes
- **Comprehensive scans**: 30-60 minutes

### Resource Usage
- CPU: Moderate during scan execution
- Memory: ~500MB-1GB per container
- Storage: ~10-50MB per report (varies by findings count)

## Troubleshooting

### Common Issues

#### 1. Prowler Command Not Found
```bash
# Check if Prowler is installed
prowler --version

# If missing, rebuild container
docker-compose build --no-cache
```

#### 2. Permission Errors
```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify IAM permissions (Prowler needs read-only access to all services)
```

#### 3. No Reports Generated
```bash
# Check output directory permissions
ls -la /output/prowler/reports/

# Create directories if missing
mkdir -p /output/prowler/reports
```

#### 4. Python Import Errors
```bash
# Check Python path
echo $PYTHONPATH

# Verify Python packages
python3 -c "import prowler; print('Prowler imported successfully')"
```

### Logging and Debugging

Enable verbose logging:
```bash
# Set log level in environment
export PROWLER_LOG_LEVEL=DEBUG

# Run with verbose output
./run-prowler-assessment.sh cis
```

## Best Practices

### 1. Regular Assessment Schedule
- **Daily**: Critical findings scan
- **Weekly**: Service-specific scans
- **Monthly**: Full compliance assessments
- **Quarterly**: All frameworks assessment

### 2. Report Management
- Archive old reports regularly
- Use meaningful naming conventions
- Export critical findings to ticketing systems

### 3. Remediation Workflow
1. Run critical findings scan
2. Export to CSV for tracking
3. Assign remediation tasks
4. Re-scan to verify fixes
5. Generate compliance reports

### 4. Integration with CI/CD
Consider integrating Prowler scans into deployment pipelines:
```bash
# Example CI/CD integration
./quick-prowler-scan.sh critical
if [ $? -ne 0 ]; then
    echo "Critical security issues found - blocking deployment"
    exit 1
fi
```

## Advanced Configuration

### Custom Check Lists
Create custom check configurations:
```bash
# Run specific checks only
prowler aws --check-list \
    iam_user_console_access_unused \
    s3_bucket_public_read \
    ec2_instance_public_ip
```

### Region-Specific Scans
Target specific AWS regions:
```bash
# Scan specific region
export AWS_DEFAULT_REGION=eu-west-1
./run-prowler-assessment.sh cis
```

### Output Customization
Modify output formats and locations:
```bash
# Custom output directory
export PROWLER_OUTPUT_DIR=/custom/path
./run-prowler-assessment.sh cis
```

## Security Considerations

### 1. Container Security
- Containers run with read-only credential mounts
- No persistent credentials stored in containers
- Isolated networks for each account

### 2. Data Handling
- Reports may contain sensitive information
- Use appropriate access controls on output directories
- Consider encryption for report storage

### 3. Compliance
- Prowler findings should be reviewed by qualified personnel
- Use framework-specific reports for audit purposes
- Maintain assessment history for compliance tracking

## Support and Resources

### Documentation
- [Official Prowler Documentation](https://prowler.pro/)
- [AWS Security Hub User Guide](https://docs.aws.amazon.com/securityhub/)
- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)

### Community
- [Prowler GitHub Repository](https://github.com/prowler-cloud/prowler)
- [AWS Security Blog](https://aws.amazon.com/blogs/security/)

### Updates
- Prowler is updated regularly with new checks
- Rebuild containers periodically to get latest version
- Review changelog for new features and compliance frameworks
