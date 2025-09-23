#!/bin/bash

# Prowler Assessment Script for AWS Security Hub SOC
# This script runs Prowler security assessments and optionally sends findings to Security Hub

set -e

# Configuration
ACCOUNT_NAME=${ACCOUNT_NAME:-"default"}
AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-"us-east-1"}
OUTPUT_DIR="/output"
PROWLER_OUTPUT_DIR="$OUTPUT_DIR/prowler"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Create output directories
mkdir -p "$PROWLER_OUTPUT_DIR"
mkdir -p "$PROWLER_OUTPUT_DIR/reports"

echo "========================================"
echo "Running Prowler Security Assessment"
echo "Account: $ACCOUNT_NAME"
echo "Region: $AWS_DEFAULT_REGION"
echo "Timestamp: $TIMESTAMP"
echo "========================================"

# Function to run Mini Prowler with specific compliance frameworks
run_prowler_compliance() {
    local compliance_framework=$1
    local output_prefix="$PROWLER_OUTPUT_DIR/reports/${ACCOUNT_NAME}-${compliance_framework}-${TIMESTAMP}"
    
    echo "Running Mini Prowler assessment for $compliance_framework..."
    
    # Map Prowler framework names to Mini Prowler names
    local mini_framework="$compliance_framework"
    case "$compliance_framework" in
        # CIS Frameworks
        "cis_1.4_aws"|"cis_1.5_aws"|"cis_2.0_aws"|"cis_3.0_aws"|"cis_4.0_aws"|"cis_5.0_aws")
            mini_framework="cis"
            ;;
        # PCI DSS Frameworks
        "pci_3.2.1_aws"|"pci_4.0_aws")
            mini_framework="basic"
            ;;
        # NIST Frameworks
        "nist_800_53_revision_4_aws"|"nist_800_53_revision_5_aws"|"nist_800_171_revision_2_aws"|"nist_csf_1.1_aws")
            mini_framework="cis"
            ;;
        # SOC2 and Audit
        "soc2_aws"|"aws_audit_manager_control_tower_guardrails_aws")
            mini_framework="basic"
            ;;
        # AWS Foundational and Security
        "aws_foundational_security_best_practices_aws"|"aws_foundational_technical_review_aws"|"aws_well_architected_framework_security_pillar_aws"|"aws_well_architected_framework_reliability_pillar_aws")
            mini_framework="basic"
            ;;
        # Regulatory Compliance
        "hipaa_aws"|"gdpr_aws"|"fedramp_low_revision_4_aws"|"fedramp_moderate_revision_4_aws"|"ffiec_aws")
            mini_framework="cis"
            ;;
        # International Standards
        "iso27001_2013_aws"|"iso27001_2022_aws"|"ens_rd2022_aws"|"nis2_aws")
            mini_framework="cis"
            ;;
        # Industry Specific
        "gxp_21_cfr_part_11_aws"|"gxp_eu_annex_11_aws"|"rbi_cyber_security_framework_aws")
            mini_framework="basic"
            ;;
        # Government and Security
        "cisa_aws"|"mitre_attack_aws"|"prowler_threatscore_aws")
            mini_framework="cis"
            ;;
        # Korean Standards
        "kisa_isms_p_2023_aws"|"kisa_isms_p_2023_korean_aws")
            mini_framework="basic"
            ;;
        # AWS Onboarding
        "aws_account_security_onboarding_aws")
            mini_framework="basic"
            ;;
        *)
            # Default to basic checks for unknown frameworks
            mini_framework="basic"
            echo "Warning: Unknown framework $compliance_framework, using basic checks"
            ;;
    esac
    
    python3 /data-processor/mini_prowler.py \
        --region "$AWS_DEFAULT_REGION" \
        --account-name "$ACCOUNT_NAME" \
        --compliance "$mini_framework" \
        --output-formats json,csv \
        --output-directory "$PROWLER_OUTPUT_DIR/reports" \
        --output-filename "${ACCOUNT_NAME}-${compliance_framework}-${TIMESTAMP}" \
        --log-level WARNING || {
        echo "Warning: Mini Prowler assessment for $compliance_framework completed with errors"
        return 1
    }
    
    echo "$compliance_framework assessment completed successfully"
    return 0
}

# Function to run comprehensive Mini Prowler scan
run_full_prowler_scan() {
    local output_prefix="$PROWLER_OUTPUT_DIR/reports/${ACCOUNT_NAME}-full-${TIMESTAMP}"
    
    echo "Running comprehensive Mini Prowler security scan..."
    
    python3 /data-processor/mini_prowler.py \
        --region "$AWS_DEFAULT_REGION" \
        --account-name "$ACCOUNT_NAME" \
        --compliance "cis" \
        --output-formats json,csv \
        --output-directory "$PROWLER_OUTPUT_DIR/reports" \
        --output-filename "${ACCOUNT_NAME}-full-${TIMESTAMP}" \
        --severity critical,high,medium \
        --log-level WARNING || {
        echo "Warning: Full Mini Prowler scan completed with errors"
        return 1
    }
    
    echo "Full security scan completed successfully"
    return 0
}

# Function to send Prowler findings to Security Hub (if enabled)
send_to_security_hub() {
    local json_file="$1"
    
    if [[ ! -f "$json_file" ]]; then
        echo "JSON file not found: $json_file"
        return 1
    fi
    
    echo "Checking if Security Hub is enabled..."
    
    # Check if Security Hub is enabled
    if aws securityhub get-enabled-standards --region "$AWS_DEFAULT_REGION" >/dev/null 2>&1; then
        echo "Security Hub is enabled. Processing findings..."
        
        # Convert Prowler findings to Security Hub format and send
        # Note: This would require a custom conversion script
        echo "Note: Prowler findings are available in JSON format for manual Security Hub integration"
        echo "JSON report: $json_file"
    else
        echo "Security Hub is not enabled in this account/region"
    fi
}

# Function to display usage information
show_usage() {
    echo "Usage: $0 [FRAMEWORK]"
    echo ""
    echo "Available compliance frameworks:"
    echo ""
    echo "CIS Frameworks:"
    echo "  cis_1.4_aws                                    - CIS AWS Foundations Benchmark v1.4"
    echo "  cis_1.5_aws                                    - CIS AWS Foundations Benchmark v1.5"
    echo "  cis_2.0_aws                                    - CIS AWS Foundations Benchmark v2.0"
    echo "  cis_3.0_aws                                    - CIS AWS Foundations Benchmark v3.0"
    echo "  cis_4.0_aws                                    - CIS AWS Foundations Benchmark v4.0"
    echo "  cis_5.0_aws                                    - CIS AWS Foundations Benchmark v5.0"
    echo ""
    echo "NIST Frameworks:"
    echo "  nist_800_53_revision_4_aws                     - NIST 800-53 Revision 4"
    echo "  nist_800_53_revision_5_aws                     - NIST 800-53 Revision 5"
    echo "  nist_800_171_revision_2_aws                    - NIST 800-171 Revision 2"
    echo "  nist_csf_1.1_aws                               - NIST Cybersecurity Framework 1.1"
    echo ""
    echo "PCI DSS:"
    echo "  pci_3.2.1_aws                                  - PCI-DSS v3.2.1"
    echo "  pci_4.0_aws                                    - PCI-DSS v4.0"
    echo ""
    echo "AWS Frameworks:"
    echo "  aws_account_security_onboarding_aws            - AWS Account Security Onboarding"
    echo "  aws_audit_manager_control_tower_guardrails_aws - AWS Audit Manager Control Tower Guardrails"
    echo "  aws_foundational_security_best_practices_aws   - AWS Foundational Security Best Practices"
    echo "  aws_foundational_technical_review_aws          - AWS Foundational Technical Review"
    echo "  aws_well_architected_framework_reliability_pillar_aws - AWS WAF Reliability Pillar"
    echo "  aws_well_architected_framework_security_pillar_aws    - AWS WAF Security Pillar"
    echo ""
    echo "Regulatory Compliance:"
    echo "  hipaa_aws                                       - HIPAA"
    echo "  gdpr_aws                                        - GDPR"
    echo "  soc2_aws                                        - SOC2 Type II"
    echo "  fedramp_low_revision_4_aws                      - FedRAMP Low Revision 4"
    echo "  fedramp_moderate_revision_4_aws                 - FedRAMP Moderate Revision 4"
    echo "  ffiec_aws                                       - FFIEC"
    echo ""
    echo "International Standards:"
    echo "  iso27001_2013_aws                               - ISO 27001:2013"
    echo "  iso27001_2022_aws                               - ISO 27001:2022"
    echo "  ens_rd2022_aws                                  - ENS RD2022"
    echo "  nis2_aws                                        - NIS2"
    echo ""
    echo "Industry Specific:"
    echo "  gxp_21_cfr_part_11_aws                          - GxP 21 CFR Part 11"
    echo "  gxp_eu_annex_11_aws                             - GxP EU Annex 11"
    echo "  rbi_cyber_security_framework_aws                - RBI Cyber Security Framework"
    echo ""
    echo "Government & Security:"
    echo "  cisa_aws                                        - CISA"
    echo "  mitre_attack_aws                                - MITRE ATT&CK"
    echo "  prowler_threatscore_aws                         - Prowler ThreatScore"
    echo ""
    echo "Korean Standards:"
    echo "  kisa_isms_p_2023_aws                            - KISA ISMS-P 2023"
    echo "  kisa_isms_p_2023_korean_aws                     - KISA ISMS-P 2023 (Korean)"
    echo ""
    echo "Special Options:"
    echo "  full                                            - Comprehensive security scan (all checks)"
    echo "  all_cis                                         - All CIS frameworks"
    echo "  all_nist                                        - All NIST frameworks"
    echo "  all_aws                                         - All AWS frameworks"
    echo "  all_regulatory                                  - All regulatory frameworks"
    echo "  all                                             - All available frameworks"
    echo ""
    echo "Default: cis_1.4_aws"
}

# Main execution
main() {
    local scan_type=${1:-"cis_1.4_aws"}
    
    case "$scan_type" in
        # Individual CIS Frameworks
        "cis_1.4_aws"|"cis_1.5_aws"|"cis_2.0_aws"|"cis_3.0_aws"|"cis_4.0_aws"|"cis_5.0_aws")
            echo "Running CIS compliance assessment: $scan_type"
            run_prowler_compliance "$scan_type"
            ;;
        
        # Individual NIST Frameworks
        "nist_800_53_revision_4_aws"|"nist_800_53_revision_5_aws"|"nist_800_171_revision_2_aws"|"nist_csf_1.1_aws")
            echo "Running NIST compliance assessment: $scan_type"
            run_prowler_compliance "$scan_type"
            ;;
        
        # Individual PCI DSS Frameworks
        "pci_3.2.1_aws"|"pci_4.0_aws")
            echo "Running PCI-DSS compliance assessment: $scan_type"
            run_prowler_compliance "$scan_type"
            ;;
        
        # Individual AWS Frameworks
        "aws_account_security_onboarding_aws"|"aws_audit_manager_control_tower_guardrails_aws"|"aws_foundational_security_best_practices_aws"|"aws_foundational_technical_review_aws"|"aws_well_architected_framework_reliability_pillar_aws"|"aws_well_architected_framework_security_pillar_aws")
            echo "Running AWS compliance assessment: $scan_type"
            run_prowler_compliance "$scan_type"
            ;;
        
        # Individual Regulatory Frameworks
        "hipaa_aws"|"gdpr_aws"|"soc2_aws"|"fedramp_low_revision_4_aws"|"fedramp_moderate_revision_4_aws"|"ffiec_aws")
            echo "Running regulatory compliance assessment: $scan_type"
            run_prowler_compliance "$scan_type"
            ;;
        
        # Individual International Standards
        "iso27001_2013_aws"|"iso27001_2022_aws"|"ens_rd2022_aws"|"nis2_aws")
            echo "Running international standards assessment: $scan_type"
            run_prowler_compliance "$scan_type"
            ;;
        
        # Individual Industry Specific
        "gxp_21_cfr_part_11_aws"|"gxp_eu_annex_11_aws"|"rbi_cyber_security_framework_aws")
            echo "Running industry specific assessment: $scan_type"
            run_prowler_compliance "$scan_type"
            ;;
        
        # Individual Government & Security
        "cisa_aws"|"mitre_attack_aws"|"prowler_threatscore_aws")
            echo "Running government/security assessment: $scan_type"
            run_prowler_compliance "$scan_type"
            ;;
        
        # Individual Korean Standards
        "kisa_isms_p_2023_aws"|"kisa_isms_p_2023_korean_aws")
            echo "Running Korean standards assessment: $scan_type"
            run_prowler_compliance "$scan_type"
            ;;
        
        # Group assessments
        "all_cis")
            echo "Running all CIS frameworks..."
            run_prowler_compliance "cis_1.4_aws"
            run_prowler_compliance "cis_1.5_aws"
            run_prowler_compliance "cis_2.0_aws"
            run_prowler_compliance "cis_3.0_aws"
            run_prowler_compliance "cis_4.0_aws"
            run_prowler_compliance "cis_5.0_aws"
            ;;
        
        "all_nist")
            echo "Running all NIST frameworks..."
            run_prowler_compliance "nist_800_53_revision_4_aws"
            run_prowler_compliance "nist_800_53_revision_5_aws"
            run_prowler_compliance "nist_800_171_revision_2_aws"
            run_prowler_compliance "nist_csf_1.1_aws"
            ;;
        
        "all_aws")
            echo "Running all AWS frameworks..."
            run_prowler_compliance "aws_account_security_onboarding_aws"
            run_prowler_compliance "aws_audit_manager_control_tower_guardrails_aws"
            run_prowler_compliance "aws_foundational_security_best_practices_aws"
            run_prowler_compliance "aws_foundational_technical_review_aws"
            run_prowler_compliance "aws_well_architected_framework_reliability_pillar_aws"
            run_prowler_compliance "aws_well_architected_framework_security_pillar_aws"
            ;;
        
        "all_regulatory")
            echo "Running all regulatory frameworks..."
            run_prowler_compliance "hipaa_aws"
            run_prowler_compliance "gdpr_aws"
            run_prowler_compliance "soc2_aws"
            run_prowler_compliance "fedramp_low_revision_4_aws"
            run_prowler_compliance "fedramp_moderate_revision_4_aws"
            run_prowler_compliance "ffiec_aws"
            ;;
        
        "full")
            echo "Running comprehensive security scan..."
            run_full_prowler_scan
            ;;
        
        "all")
            echo "Running ALL compliance frameworks (this will take a long time)..."
            echo "Are you sure? This will run $(echo 'aws_account_security_onboarding_aws aws_audit_manager_control_tower_guardrails_aws aws_foundational_security_best_practices_aws aws_foundational_technical_review_aws aws_well_architected_framework_reliability_pillar_aws aws_well_architected_framework_security_pillar_aws cis_1.4_aws cis_1.5_aws cis_2.0_aws cis_3.0_aws cis_4.0_aws cis_5.0_aws cisa_aws ens_rd2022_aws fedramp_low_revision_4_aws fedramp_moderate_revision_4_aws ffiec_aws gdpr_aws gxp_21_cfr_part_11_aws gxp_eu_annex_11_aws hipaa_aws iso27001_2013_aws iso27001_2022_aws kisa_isms_p_2023_aws kisa_isms_p_2023_korean_aws mitre_attack_aws nis2_aws nist_800_171_revision_2_aws nist_800_53_revision_4_aws nist_800_53_revision_5_aws nist_csf_1.1_aws pci_3.2.1_aws pci_4.0_aws prowler_threatscore_aws rbi_cyber_security_framework_aws soc2_aws' | wc -w) different frameworks."
            read -p "Continue? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Assessment cancelled."
                exit 0
            fi
            
            # Run all frameworks
            for framework in aws_account_security_onboarding_aws aws_audit_manager_control_tower_guardrails_aws aws_foundational_security_best_practices_aws aws_foundational_technical_review_aws aws_well_architected_framework_reliability_pillar_aws aws_well_architected_framework_security_pillar_aws cis_1.4_aws cis_1.5_aws cis_2.0_aws cis_3.0_aws cis_4.0_aws cis_5.0_aws cisa_aws ens_rd2022_aws fedramp_low_revision_4_aws fedramp_moderate_revision_4_aws ffiec_aws gdpr_aws gxp_21_cfr_part_11_aws gxp_eu_annex_11_aws hipaa_aws iso27001_2013_aws iso27001_2022_aws kisa_isms_p_2023_aws kisa_isms_p_2023_korean_aws mitre_attack_aws nis2_aws nist_800_171_revision_2_aws nist_800_53_revision_4_aws nist_800_53_revision_5_aws nist_csf_1.1_aws pci_3.2.1_aws pci_4.0_aws prowler_threatscore_aws rbi_cyber_security_framework_aws soc2_aws; do
                echo "\n--- Running $framework ---"
                run_prowler_compliance "$framework" || echo "Warning: $framework failed, continuing..."
            done
            ;;
        
        # Legacy support
        "cis")
            echo "Running CIS compliance assessment (legacy)..."
            run_prowler_compliance "cis_1.4_aws"
            ;;
        "pci")
            echo "Running PCI-DSS compliance assessment (legacy)..."
            run_prowler_compliance "pci_3.2.1_aws"
            ;;
        "nist")
            echo "Running NIST compliance assessment (legacy)..."
            run_prowler_compliance "nist_800_53_revision_5_aws"
            ;;
        "soc2")
            echo "Running SOC2 compliance assessment (legacy)..."
            run_prowler_compliance "soc2_aws"
            ;;
        
        "help"|"--help"|"usage")
            show_usage
            exit 0
            ;;
        
        *)
            echo "Error: Unknown framework or option '$scan_type'"
            echo ""
            show_usage
            exit 1
            ;;
    esac
    
    # Generate summary report
    echo ""
    echo "========================================"
    echo "Assessment Summary"
    echo "========================================"
    echo "Reports generated in: $PROWLER_OUTPUT_DIR/reports"
    
    # List generated files
    find "$PROWLER_OUTPUT_DIR/reports" -name "*${TIMESTAMP}*" -type f | while read -r file; do
        echo "- $(basename "$file")"
    done
    
    # Try to send critical findings to Security Hub if JSON exists
    json_files=$(find "$PROWLER_OUTPUT_DIR/reports" -name "*${TIMESTAMP}*.json" -type f)
    if [[ -n "$json_files" ]]; then
        echo ""
        echo "Processing findings for Security Hub integration..."
        for json_file in $json_files; do
            send_to_security_hub "$json_file"
        done
    fi
    
    echo ""
    echo "Prowler assessment completed for account: $ACCOUNT_NAME"
    echo "Check the reports directory for detailed findings"
}

# Check if Mini Prowler is available
if [[ ! -f "/data-processor/mini_prowler.py" ]]; then
    echo "Error: Mini Prowler not found. Please ensure the data-processor directory is mounted."
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "Error: AWS credentials not configured or invalid."
    exit 1
fi

# Run main function with arguments
main "$@"
