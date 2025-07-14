# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-01-14

### Added
- New `disable-security-hub.sh` script for safely disabling Security Hub and cleaning up resources
- Comprehensive cleanup functionality including:
  - Security standards disabling (CIS, PCI-DSS, AWS Foundational Security Best Practices)
  - Member account removal and disassociation
  - Custom insights cleanup
  - Action targets cleanup
- Enhanced error handling and status checking
- Detailed logging and progress reporting

### Changed
- Updated README.md to clarify target audience (SysOps and audit teams)
- Enhanced documentation with real-world use cases and benefits
- Improved project description to emphasize landing zone audit capabilities

### Fixed
- Removed dependency on jq in disable script (not available in container)
- Fixed AWS CLI command names for compatibility
- Added proper error handling for disabled Security Hub scenarios

### Security
- Implemented GitHub branch protection rules with required pull request reviews
- Added signed commit requirements
- Enhanced security workflow with protected main branch

## [1.0.0] - 2024-01-10

### Added
- Initial release of AWS Security Hub SOC multi-account management system
- Docker Compose setup for managing multiple AWS accounts
- Comprehensive set of Security Hub automation scripts:
  - `enable-security-hub.sh` - Enable Security Hub and compliance standards
  - `get-findings.sh` - Retrieve all Security Hub findings
  - `get-critical-findings.sh` - Filter critical and high severity findings
  - `get-compliance-summary.sh` - Generate compliance reports
  - `aggregate-findings.sh` - Aggregate findings across accounts
  - `export-findings-csv.sh` - Export findings to CSV format
  - `remediate-findings.sh` - Automated remediation for common issues
  - `monitor-compliance.sh` - Track compliance scores over time
- Support for AWS Foundational Security Best Practices, CIS, and PCI-DSS standards
- Region configuration set to eu-west-3
- Comprehensive documentation and setup instructions
- Security-focused architecture with read-only credential mounts
- Output isolation per account
- MIT License

### Security
- Implemented `.gitignore` to prevent credential commits
- Read-only volume mounts for AWS credentials
- Isolated containers per account
- No hardcoded secrets in scripts

[1.1.0]: https://github.com/4math2379/aws-security-hub-soc/releases/tag/v1.1.0
[1.0.0]: https://github.com/4math2379/aws-security-hub-soc/releases/tag/v1.0.0
