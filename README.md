# AWS Security Hub SOC with Prowler Integration

## Overview

This project provides comprehensive AWS security assessment capabilities by combining AWS Security Hub findings extraction with Prowler CLI security auditing across multiple accounts. It's designed for SysOps and audit teams managing AWS landing zones and multi-account environments.

### Key Features
- **AWS Security Hub Integration**: Extract and analyze native AWS security findings
- **Prowler CLI Integration**: 400+ security checks across 30+ AWS services
- **Multi-Compliance Framework Support**: CIS, NIST, PCI-DSS, SOC2, and more
- **Multi-Account Management**: Isolated containers for each AWS account
- **Automated Reporting**: JSON, CSV, and HTML report generation
- **Executive Dashboards**: Flask-based web interface for findings visualization
- **Cross-Account Aggregation**: Consolidated reporting across all accounts

## Quick Start

### Prerequisites
- [Docker](https://www.docker.com/get-started) installed on your system
- AWS credentials configured for each account
- Appropriate IAM permissions for Security Hub and Prowler (ReadOnlyAccess recommended)

### Setup

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd aws-security-hub-soc
   ```

2. **Configure your AWS credentials:**
   ```bash
   # Create credential directories for each account
   mkdir -p aws-credentials/{latecoere.aero,account2,account3,master}
   
   # Place AWS credentials and config files in respective directories
   # aws-credentials/latecoere.aero/credentials
   # aws-credentials/latecoere.aero/config
   ```

3. **Build and Run:**
   ```bash
   # Build containers with Prowler integration
   docker-compose build
   
   # Start all services
   docker-compose up -d
   ```

4. **Run Your First Security Assessment:**
   ```bash
   # Connect to account container
   docker exec -it latecoere-aero bash
   
   # Run comprehensive security assessment
   ./run-comprehensive-security-assessment.sh full
   
   # Or run quick Prowler scan
   ./quick-prowler-scan.sh cis
   ```

5. **Access the Dashboard:**
   - Open [http://localhost:5001](http://localhost:5001) in your browser to view the findings.

### Usage Examples

#### Security Hub Operations
```bash
# Extract Security Hub findings
docker exec latecoere-aero /aws-scripts/get-findings.sh

# Get critical findings only
docker exec latecoere-aero /aws-scripts/get-critical-findings.sh

# Generate compliance summary
docker exec latecoere-aero /aws-scripts/get-compliance-summary.sh
```

#### Prowler Security Assessments
```bash
# CIS AWS Foundations Benchmark
docker exec latecoere-aero ./run-prowler-assessment.sh cis

# PCI-DSS compliance assessment
docker exec latecoere-aero ./run-prowler-assessment.sh pci

# Quick critical findings scan
docker exec latecoere-aero ./quick-prowler-scan.sh critical

# Comprehensive assessment (Security Hub + Prowler)
docker exec latecoere-aero ./run-comprehensive-security-assessment.sh full
```

#### Cross-Account Aggregation
```bash
# Aggregate Prowler findings across all accounts
docker exec aws-security-hub-aggregator ./aggregate-prowler-findings.sh all

# Generate executive summary
docker exec aws-security-hub-aggregator ./aggregate-prowler-findings.sh summary
```

## Project Structure

### Core Components
- **docker-compose.yml:** Multi-account container configuration with Prowler
- **Dockerfile:** Multi-stage build with AWS CLI and Prowler CLI
- **aws-scripts/:** Security assessment and reporting scripts
- **docs/:** Comprehensive documentation including Prowler integration guide

### Key Directories
```
aws-security-hub-soc/
├── aws-credentials/          # AWS credentials per account
├── aws-scripts/             # Assessment and reporting scripts
│   ├── run-prowler-assessment.sh
│   ├── get-prowler-critical-findings.sh
│   ├── aggregate-prowler-findings.sh
│   ├── run-comprehensive-security-assessment.sh
│   └── quick-prowler-scan.sh
├── docs/                    # Documentation
│   └── PROWLER_INTEGRATION.md
├── output/                  # Generated reports (account-specific)
│   ├── latecoere.aero/
│   ├── account2/
│   └── account3/
├── templates/               # Flask dashboard templates
└── data-processor/          # Report processing utilities
```

## Compliance Frameworks

This project supports multiple security compliance frameworks through Prowler integration:

| Framework | Description | Best For |
|-----------|-------------|----------|
| **CIS 1.4** | Center for Internet Security AWS Foundations | General security baseline, recommended starting point |
| **PCI-DSS 3.2.1** | Payment Card Industry Data Security Standard | Organizations handling payment card data |
| **NIST 800-53 Rev 5** | National Institute of Standards and Technology | Government and federal compliance requirements |
| **SOC2 Type II** | Service Organization Control 2 | Service providers and SaaS companies |

### Quick Framework Assessment
```bash
# CIS compliance (recommended first assessment)
docker exec latecoere-aero ./run-prowler-assessment.sh cis

# PCI-DSS for payment environments
docker exec latecoere-aero ./run-prowler-assessment.sh pci

# Run all frameworks for comprehensive coverage
docker exec latecoere-aero ./run-prowler-assessment.sh all
```

## Report Types and Locations

### Account-Specific Reports
Each account generates isolated reports in `./output/[account-name]/`:
- **Security Hub Reports**: `security-hub/findings-*.json`
- **Prowler Reports**: `prowler/reports/[account]-[framework]-[timestamp].*`
- **Combined Reports**: `combined-reports/combined-security-assessment-*.txt`

### Aggregated Reports
Cross-account analysis available in `./output/aggregated/prowler/aggregated/`:
- **Executive Summary**: `executive-summary-*.txt`
- **Consolidated CSV**: `consolidated-critical-findings-*.csv`
- **Risk Assessment**: `aggregated-findings-by-severity-*.json`

## Advanced Usage

### Docker Compose Configurations

```bash
# Full setup with all services
docker-compose up -d

# Minimal setup for quick testing
docker-compose -f docker-compose-minimal.yml up -d

# Simple test container
docker-compose -f docker-compose-simple.yml up -d
```

### Container Management
```bash
# Rebuild with latest Prowler version
docker-compose build --no-cache

# View container logs
docker-compose logs -f latecoere-aero

# Execute commands in specific account container
docker exec -it latecoere-aero bash
```

## Documentation

- **[Prowler Integration Guide](docs/PROWLER_INTEGRATION.md)**: Comprehensive guide to Prowler CLI integration
- **[Multi-Stage Build Documentation](docs/MULTI_STAGE_BUILD.md)**: Container optimization details
- **[Changelog](CHANGELOG.md)**: Version history and updates

## Target Audience

### SysOps Teams
- **Daily Operations**: Quick security scans and critical findings monitoring
- **Incident Response**: Rapid security assessment during security events
- **Compliance Monitoring**: Regular framework-specific assessments

### Audit Teams
- **Compliance Reporting**: Generate framework-specific compliance reports
- **Executive Summaries**: High-level security posture reporting
- **Evidence Collection**: Export detailed findings for audit documentation

### Security Teams
- **Continuous Monitoring**: Automated security assessments across accounts
- **Vulnerability Management**: Identify and track security weaknesses
- **Risk Assessment**: Cross-account security posture evaluation

## Benefits

- **Comprehensive Coverage**: Combines AWS native (Security Hub) and community-driven (Prowler) security checks
- **Multi-Account Scale**: Designed for enterprise AWS environments with multiple accounts
- **Compliance Ready**: Support for major compliance frameworks out of the box
- **Automated Reporting**: Generates executive-ready reports and technical details
- **Containerized Deployment**: Consistent execution environment with Docker
- **Flexible Assessment**: Choose from quick scans to comprehensive audits

## Getting Help

1. **Review Documentation**: Start with [Prowler Integration Guide](docs/PROWLER_INTEGRATION.md)
2. **Check Troubleshooting**: Common issues and solutions in the integration guide
3. **Examine Logs**: Use `docker-compose logs [container-name]` for debugging
4. **Test Credentials**: Verify AWS access with `aws sts get-caller-identity`
5. **Validate Prowler**: Check installation with `docker exec [container] prowler --version`

