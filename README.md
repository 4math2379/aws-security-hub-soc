# AWS Security Hub SOC

[![Release](https://img.shields.io/github/v/release/4math2379/aws-security-hub-soc)](https://github.com/4math2379/aws-security-hub-soc/releases)
[![AWS](https://img.shields.io/badge/AWS-Security%20Hub-FF9900?logo=amazon-aws)](https://aws.amazon.com/security-hub/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)](https://docs.docker.com/compose/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://makeapullrequest.com)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://github.com/4math2379/aws-security-hub-soc/graphs/commit-activity)
[![Version](https://img.shields.io/badge/version-v1.0.0-blue)](https://github.com/4math2379/aws-security-hub-soc/releases/tag/v1.0.0)
[![Security](https://img.shields.io/badge/Security-SOC%202-red)](https://www.sans.org/cyber-security-courses/security-operations-essentials/)

A comprehensive Docker-based solution that enables SysOps and audit teams to apply SOC methodologies when managing AWS Security Hub across multiple AWS accounts and landing zones.

## Overview

This repository provides a containerized approach to managing AWS Security Hub findings, compliance monitoring, and automated remediation across multiple AWS accounts. Originally developed for auditing multiple AWS landing zones, this tool empowers SysOps and audit teams to leverage SOC (Security Operations Center) methodologies in their security assessments and compliance monitoring workflows.

### Target Audience

- **SysOps Teams**: Streamline security monitoring across multiple AWS accounts
- **Audit Teams**: Conduct comprehensive security audits using SOC best practices
- **Cloud Security Professionals**: Assess and monitor multi-account AWS environments
- **Landing Zone Administrators**: Maintain security compliance across complex AWS organizations

### Key Use Cases

- **Multi-Landing Zone Audits**: Efficiently audit security posture across multiple customer landing zones
- **Compliance Assessment**: Track and report on compliance against multiple security standards
- **Security Finding Aggregation**: Consolidate security findings from numerous AWS accounts
- **Automated Reporting**: Generate audit-ready reports for stakeholder review

## Features

- **Multi-Account Support**: Manage Security Hub for multiple AWS accounts simultaneously
- **Containerized Environment**: Isolated Docker containers for each account
- **Automated Scripts**: Collection of bash scripts for common Security Hub operations
- **Compliance Monitoring**: Track compliance scores across different security standards
- **Finding Management**: Export, analyze, and remediate security findings
- **CSV Export**: Generate reports in CSV format for further analysis

## Supported AWS Services & Standards

### Security Standards
- AWS Foundational Security Best Practices v1.0.0
- CIS AWS Foundations Benchmark v1.2.0
- PCI DSS v3.2.1
- AWS Well-Architected Framework

### Integrated Services
- AWS Security Hub
- AWS Config
- Amazon GuardDuty
- AWS Inspector
- AWS CloudTrail
- AWS IAM
- Amazon S3
- Amazon EC2

## Prerequisites

- Docker and Docker Compose installed
- AWS credentials configured for each account
- AWS Security Hub permissions in target accounts

## Project Structure

```
aws-sec/
├── docker-compose.yml          # Docker composition for multi-account setup
├── aws-credentials/           # AWS credentials for each account
│   ├── account1/
│   ├── account2/
│   ├── account3/
│   └── master/
├── aws-scripts/              # Security Hub automation scripts
│   ├── enable-security-hub.sh
│   ├── get-findings.sh
│   ├── get-critical-findings.sh
│   ├── get-compliance-summary.sh
│   ├── aggregate-findings.sh
│   ├── export-findings-csv.sh
│   ├── remediate-findings.sh
│   └── monitor-compliance.sh
├── output/                   # Output directory for reports
│   ├── account1/
│   ├── account2/
│   ├── account3/
│   └── aggregated/
└── docker/                   # Docker-related files

```

## Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/4math2379/aws-security-hub-soc.git
   cd aws-security-hub-soc
   ```

2. **Configure AWS credentials**
   
   Place your AWS credentials in the appropriate directories:
   ```bash
   # For each account, create credentials and config files
   mkdir -p aws-credentials/account1
   # Add credentials and config files
   ```

3. **Create output directories**
   ```bash
   mkdir -p output/{account1,account2,account3,aggregated}
   ```

4. **Start the containers**
   ```bash
   docker-compose up -d
   ```

## Usage

### Access a specific account container
```bash
# For account 1
docker-compose exec awscli-account1 bash

# For account 2
docker-compose exec awscli-account2 bash

# For the aggregator (master account)
docker-compose exec security-hub-aggregator bash
```

### Run Security Hub scripts

Inside any container, you can run the following scripts:

1. **Enable Security Hub**
   ```bash
   ./enable-security-hub.sh
   ```

2. **Get all findings**
   ```bash
   ./get-findings.sh
   ```

3. **Get critical and high severity findings**
   ```bash
   ./get-critical-findings.sh
   ```

4. **Export findings to CSV**
   ```bash
   ./export-findings-csv.sh
   ```

5. **Monitor compliance**
   ```bash
   ./monitor-compliance.sh
   ```

6. **Remediate findings**
   ```bash
   ./remediate-findings.sh
   ```

## Scripts Description

### enable-security-hub.sh
- Enables AWS Security Hub if not already enabled
- Activates major compliance standards (AWS Foundational Security Best Practices, CIS, PCI-DSS)

### get-findings.sh
- Retrieves all Security Hub findings
- Displays a summary table
- Saves detailed JSON output

### get-critical-findings.sh
- Filters findings by CRITICAL and HIGH severity
- Provides count summaries
- Exports filtered results

### get-compliance-summary.sh
- Shows enabled standards
- Calculates compliance scores for each standard
- Generates detailed compliance reports

### export-findings-csv.sh
- Exports findings to CSV format
- Includes statistics by severity and compliance status
- Lists top resource types with findings

### monitor-compliance.sh
- Tracks compliance scores over time
- Creates timestamped JSON reports
- Maintains compliance history for trend analysis

### remediate-findings.sh
- Attempts automatic remediation for common issues
- Enables S3 bucket encryption
- Identifies security groups with unrestricted access
- Generates remediation reports

### aggregate-findings.sh
- Runs from master account
- Aggregates findings across all member accounts
- Provides cross-account visibility

## Real-World Benefits

### From Field Experience

This tool has proven invaluable during numerous customer audits, particularly when assessing:

- **Multiple Landing Zones**: Quickly switch between different customer environments without credential conflicts
- **Standardized Assessments**: Apply consistent SOC methodologies across diverse AWS architectures
- **Time Efficiency**: Reduce audit time from days to hours with automated finding aggregation
- **Comprehensive Reporting**: Generate executive-ready compliance reports across all accounts
- **Risk Prioritization**: Identify critical issues across hundreds of AWS accounts simultaneously

### Why SysOps and Audit Teams Choose This Tool

1. **Isolation**: Each AWS account runs in its own container, preventing credential leakage
2. **Repeatability**: Standardized scripts ensure consistent audits across engagements
3. **Scalability**: Easily add new accounts or landing zones as needed
4. **Auditability**: All findings and reports are timestamped and preserved
5. **SOC Methodology**: Apply proven security operations practices without a full SOC team

## Configuration

### Region Configuration
The default region is set to `eu-west-3`. To change it, modify the `AWS_DEFAULT_REGION` environment variable in `docker-compose.yml`.

### Adding New Accounts
To add a new account, add a new service in `docker-compose.yml`:
```yaml
awscli-account4:
  image: amazon/aws-cli:latest
  container_name: aws-security-hub-account4
  volumes:
    - ./aws-credentials/account4:/root/.aws:ro
    - ./aws-scripts:/aws-scripts:ro
    - ./output/account4:/output
  working_dir: /aws-scripts
  environment:
    - AWS_DEFAULT_REGION=eu-west-3
    - ACCOUNT_NAME=account4
  entrypoint: ["/bin/bash"]
  tty: true
  stdin_open: true
  networks:
    - aws-security-network
```

## Security Considerations

- AWS credentials are mounted as read-only volumes
- Each account runs in an isolated container
- Scripts directory is mounted as read-only
- Output directories are account-specific

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues, questions, or contributions, please open an issue in the GitHub repository.
