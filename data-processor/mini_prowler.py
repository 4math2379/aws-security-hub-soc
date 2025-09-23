#!/usr/bin/env python3
"""
Mini Prowler - A Python 3.7 compatible AWS security assessment tool
Provides basic Prowler-like functionality for AWS security checks
"""

import os
import sys
import json
import boto3
import argparse
from datetime import datetime
from typing import Dict, List, Any, Optional
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class MiniProwler:
    def __init__(self, region: str = 'us-east-1', account_name: str = 'default'):
        self.region = region
        self.account_name = account_name
        self.session = boto3.Session()
        self.findings = []
        
    def get_aws_clients(self):
        """Get AWS service clients"""
        clients = {}
        services = ['iam', 's3', 'ec2', 'rds', 'cloudtrail', 'config', 'guardduty', 'kms']
        
        for service in services:
            try:
                if service == 'iam':
                    # IAM is global
                    clients[service] = self.session.client(service)
                else:
                    clients[service] = self.session.client(service, region_name=self.region)
            except Exception as e:
                logger.warning(f"Could not create {service} client: {e}")
                
        return clients
        
    def check_iam_users_console_access(self, clients):
        """Check for IAM users with unused console access"""
        findings = []
        try:
            iam = clients.get('iam')
            if not iam:
                return findings
                
            users = iam.list_users()['Users']
            
            for user in users:
                username = user['UserName']
                
                try:
                    # Check if user has login profile (console access)
                    iam.get_login_profile(UserName=username)
                    
                    # Check last used
                    user_detail = iam.get_user(UserName=username)['User']
                    password_last_used = user_detail.get('PasswordLastUsed')
                    
                    if password_last_used is None:
                        findings.append({
                            'check_id': 'iam_user_console_access_unused',
                            'check_title': 'IAM user has console access but never used',
                            'status': 'FAIL',
                            'severity': 'MEDIUM',
                            'resource_id': f'arn:aws:iam::{user.get("Arn", "").split(":")[4]}:user/{username}',
                            'resource_type': 'AwsIamUser',
                            'region': 'global',
                            'status_extended': f'User {username} has console access but has never logged in',
                            'compliance_framework': 'CIS-1.4'
                        })
                    else:
                        days_since_last_use = (datetime.now(password_last_used.tzinfo) - password_last_used).days
                        if days_since_last_use > 90:
                            findings.append({
                                'check_id': 'iam_user_console_access_unused',
                                'check_title': 'IAM user console access unused for 90+ days',
                                'status': 'FAIL',
                                'severity': 'HIGH',
                                'resource_id': f'arn:aws:iam::{user.get("Arn", "").split(":")[4]}:user/{username}',
                                'resource_type': 'AwsIamUser',
                                'region': 'global',
                                'status_extended': f'User {username} has not used console access for {days_since_last_use} days',
                                'compliance_framework': 'CIS-1.4'
                            })
                            
                except iam.exceptions.NoSuchEntityException:
                    # User doesn't have console access, which is good
                    pass
                except Exception as e:
                    logger.warning(f"Error checking user {username}: {e}")
                    
        except Exception as e:
            logger.error(f"Error in IAM console access check: {e}")
            
        return findings
        
    def check_s3_bucket_public_read(self, clients):
        """Check for S3 buckets with public read access"""
        findings = []
        try:
            s3 = clients.get('s3')
            if not s3:
                return findings
                
            buckets = s3.list_buckets()['Buckets']
            
            for bucket in buckets:
                bucket_name = bucket['Name']
                
                try:
                    # Check bucket ACL
                    acl = s3.get_bucket_acl(Bucket=bucket_name)
                    
                    for grant in acl.get('Grants', []):
                        grantee = grant.get('Grantee', {})
                        permission = grant.get('Permission')
                        
                        # Check for public read access
                        if (grantee.get('URI') == 'http://acs.amazonaws.com/groups/global/AllUsers' and 
                            permission in ['READ', 'FULL_CONTROL']):
                            findings.append({
                                'check_id': 's3_bucket_public_read',
                                'check_title': 'S3 bucket allows public read access',
                                'status': 'FAIL',
                                'severity': 'CRITICAL',
                                'resource_id': f'arn:aws:s3:::{bucket_name}',
                                'resource_type': 'AwsS3Bucket',
                                'region': self.region,
                                'status_extended': f'Bucket {bucket_name} allows public read access via ACL',
                                'compliance_framework': 'CIS-1.4'
                            })
                            break
                            
                    # Check bucket policy for public access
                    try:
                        policy = s3.get_bucket_policy(Bucket=bucket_name)
                        policy_doc = json.loads(policy['Policy'])
                        
                        for statement in policy_doc.get('Statement', []):
                            if (statement.get('Effect') == 'Allow' and 
                                statement.get('Principal') == '*'):
                                findings.append({
                                    'check_id': 's3_bucket_public_read',
                                    'check_title': 'S3 bucket allows public read access via policy',
                                    'status': 'FAIL',
                                    'severity': 'CRITICAL',
                                    'resource_id': f'arn:aws:s3:::{bucket_name}',
                                    'resource_type': 'AwsS3Bucket',
                                    'region': self.region,
                                    'status_extended': f'Bucket {bucket_name} allows public access via bucket policy',
                                    'compliance_framework': 'CIS-1.4'
                                })
                                break
                                
                    except s3.exceptions.NoSuchBucketPolicy:
                        # No bucket policy is fine
                        pass
                        
                except Exception as e:
                    logger.warning(f"Error checking bucket {bucket_name}: {e}")
                    
        except Exception as e:
            logger.error(f"Error in S3 public read check: {e}")
            
        return findings
        
    def check_ec2_instances_public_ip(self, clients):
        """Check for EC2 instances with public IP addresses"""
        findings = []
        try:
            ec2 = clients.get('ec2')
            if not ec2:
                return findings
                
            instances = ec2.describe_instances()
            
            for reservation in instances['Reservations']:
                for instance in reservation['Instances']:
                    instance_id = instance['InstanceId']
                    public_ip = instance.get('PublicIpAddress')
                    
                    if public_ip and instance['State']['Name'] == 'running':
                        findings.append({
                            'check_id': 'ec2_instance_public_ip',
                            'check_title': 'EC2 instance has public IP address',
                            'status': 'FAIL',
                            'severity': 'MEDIUM',
                            'resource_id': f'arn:aws:ec2:{self.region}:{instance.get("OwnerId", "")}:instance/{instance_id}',
                            'resource_type': 'AwsEc2Instance',
                            'region': self.region,
                            'status_extended': f'Instance {instance_id} has public IP {public_ip}',
                            'compliance_framework': 'CIS-1.4'
                        })
                        
        except Exception as e:
            logger.error(f"Error in EC2 public IP check: {e}")
            
        return findings
        
    def check_rds_instances_publicly_accessible(self, clients):
        """Check for RDS instances that are publicly accessible"""
        findings = []
        try:
            rds = clients.get('rds')
            if not rds:
                return findings
                
            instances = rds.describe_db_instances()['DBInstances']
            
            for instance in instances:
                db_instance_id = instance['DBInstanceIdentifier']
                
                if instance.get('PubliclyAccessible', False):
                    findings.append({
                        'check_id': 'rds_instance_publicly_accessible',
                        'check_title': 'RDS instance is publicly accessible',
                        'status': 'FAIL',
                        'severity': 'HIGH',
                        'resource_id': instance.get('DBInstanceArn', f'rds-instance-{db_instance_id}'),
                        'resource_type': 'AwsRdsDbInstance',
                        'region': self.region,
                        'status_extended': f'RDS instance {db_instance_id} is publicly accessible',
                        'compliance_framework': 'CIS-1.4'
                    })
                    
        except Exception as e:
            logger.error(f"Error in RDS publicly accessible check: {e}")
            
        return findings
        
    def check_cloudtrail_enabled(self, clients):
        """Check if CloudTrail is enabled"""
        findings = []
        try:
            cloudtrail = clients.get('cloudtrail')
            if not cloudtrail:
                return findings
                
            trails = cloudtrail.describe_trails()['trailList']
            
            if not trails:
                findings.append({
                    'check_id': 'cloudtrail_enabled',
                    'check_title': 'CloudTrail is not enabled',
                    'status': 'FAIL',
                    'severity': 'CRITICAL',
                    'resource_id': f'arn:aws:cloudtrail:{self.region}::trail/none',
                    'resource_type': 'AwsCloudTrail',
                    'region': self.region,
                    'status_extended': 'No CloudTrail trails configured in this region',
                    'compliance_framework': 'CIS-1.4'
                })
            else:
                for trail in trails:
                    trail_name = trail['Name']
                    
                    # Check if trail is logging
                    try:
                        status = cloudtrail.get_trail_status(Name=trail_name)
                        if not status.get('IsLogging', False):
                            findings.append({
                                'check_id': 'cloudtrail_enabled',
                                'check_title': 'CloudTrail is not logging',
                                'status': 'FAIL',
                                'severity': 'HIGH',
                                'resource_id': trail.get('TrailARN', f'trail-{trail_name}'),
                                'resource_type': 'AwsCloudTrail',
                                'region': self.region,
                                'status_extended': f'CloudTrail {trail_name} exists but is not logging',
                                'compliance_framework': 'CIS-1.4'
                            })
                    except Exception as e:
                        logger.warning(f"Error checking trail status for {trail_name}: {e}")
                        
        except Exception as e:
            logger.error(f"Error in CloudTrail enabled check: {e}")
            
        return findings
        
    def run_security_checks(self, compliance_framework: str = 'cis') -> List[Dict]:
        """Run security checks based on compliance framework"""
        logger.info(f"Starting security assessment for {self.account_name} in {self.region}")
        
        clients = self.get_aws_clients()
        all_findings = []
        
        # Map compliance frameworks to check functions
        check_functions = {
            'cis': [
                self.check_iam_users_console_access,
                self.check_s3_bucket_public_read,
                self.check_ec2_instances_public_ip,
                self.check_rds_instances_publicly_accessible,
                self.check_cloudtrail_enabled,
            ],
            'basic': [
                self.check_s3_bucket_public_read,
                self.check_ec2_instances_public_ip,
                self.check_rds_instances_publicly_accessible,
            ],
            'critical': [
                self.check_s3_bucket_public_read,
                self.check_cloudtrail_enabled,
            ]
        }
        
        functions_to_run = check_functions.get(compliance_framework, check_functions['cis'])
        
        for check_function in functions_to_run:
            try:
                findings = check_function(clients)
                all_findings.extend(findings)
                logger.info(f"Completed {check_function.__name__}: {len(findings)} findings")
            except Exception as e:
                logger.error(f"Error in {check_function.__name__}: {e}")
                
        # Add pass findings for checks that had no failures
        # (This is simplified - real Prowler would check all resources and mark as PASS)
        
        logger.info(f"Security assessment completed: {len(all_findings)} total findings")
        return all_findings
        
    def generate_report(self, findings: List[Dict], output_format: str = 'json', 
                       output_file: str = None) -> str:
        """Generate report in specified format"""
        
        if output_file is None:
            timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')
            output_file = f"/output/prowler/reports/{self.account_name}-mini-prowler-{timestamp}"
            
        os.makedirs(os.path.dirname(output_file), exist_ok=True)
        
        if output_format == 'json':
            report_data = {
                'account_name': self.account_name,
                'region': self.region,
                'assessment_date': datetime.now().isoformat(),
                'tool': 'mini-prowler',
                'version': '1.0.0',
                'findings': findings,
                'summary': {
                    'total_findings': len(findings),
                    'by_severity': self._count_by_severity(findings),
                    'by_status': self._count_by_status(findings)
                }
            }
            
            json_file = f"{output_file}.json"
            with open(json_file, 'w') as f:
                json.dump(report_data, f, indent=2, default=str)
                
            logger.info(f"JSON report saved to {json_file}")
            return json_file
            
        elif output_format == 'csv':
            csv_file = f"{output_file}.csv"
            
            with open(csv_file, 'w') as f:
                # Write header
                f.write("CheckId,Severity,Title,ResourceId,Region,Status,Description,Framework\n")
                
                # Write findings
                for finding in findings:
                    row = [
                        finding.get('check_id', ''),
                        finding.get('severity', ''),
                        finding.get('check_title', '').replace(',', ';'),
                        finding.get('resource_id', ''),
                        finding.get('region', ''),
                        finding.get('status', ''),
                        finding.get('status_extended', '').replace(',', ';'),
                        finding.get('compliance_framework', '')
                    ]
                    f.write(','.join(f'"{item}"' for item in row) + '\n')
                    
            logger.info(f"CSV report saved to {csv_file}")
            return csv_file
            
        return output_file
        
    def _count_by_severity(self, findings: List[Dict]) -> Dict[str, int]:
        """Count findings by severity"""
        counts = {'CRITICAL': 0, 'HIGH': 0, 'MEDIUM': 0, 'LOW': 0, 'INFORMATIONAL': 0}
        for finding in findings:
            severity = finding.get('severity', 'UNKNOWN').upper()
            if severity in counts:
                counts[severity] += 1
        return counts
        
    def _count_by_status(self, findings: List[Dict]) -> Dict[str, int]:
        """Count findings by status"""
        counts = {'PASS': 0, 'FAIL': 0}
        for finding in findings:
            status = finding.get('status', 'UNKNOWN').upper()
            if status in counts:
                counts[status] += 1
        return counts

def main():
    parser = argparse.ArgumentParser(description='Mini Prowler - AWS Security Assessment')
    parser.add_argument('--region', default='us-east-1', help='AWS region')
    parser.add_argument('--account-name', default='default', help='Account name for reporting')
    parser.add_argument('--compliance', default='cis', choices=['cis', 'basic', 'critical'],
                       help='Compliance framework to use')
    parser.add_argument('--output-formats', default='json', help='Output formats (json,csv)')
    parser.add_argument('--output-directory', default='/output/prowler/reports', 
                       help='Output directory')
    parser.add_argument('--output-filename', help='Output filename prefix')
    parser.add_argument('--severity', help='Filter by severity (critical,high,medium,low)')
    parser.add_argument('--log-level', default='INFO', choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'])
    
    args = parser.parse_args()
    
    # Set log level
    logging.getLogger().setLevel(getattr(logging, args.log_level.upper()))
    
    # Initialize Mini Prowler
    prowler = MiniProwler(region=args.region, account_name=args.account_name)
    
    # Run security checks
    findings = prowler.run_security_checks(compliance_framework=args.compliance)
    
    # Filter by severity if specified
    if args.severity:
        severity_filters = [s.strip().upper() for s in args.severity.split(',')]
        findings = [f for f in findings if f.get('severity', '').upper() in severity_filters]
        logger.info(f"Filtered to {len(findings)} findings matching severity: {args.severity}")
    
    # Generate reports in specified formats
    formats = args.output_formats.split(',')
    
    for format_type in formats:
        format_type = format_type.strip().lower()
        
        if args.output_filename:
            output_file = os.path.join(args.output_directory, args.output_filename)
        else:
            timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')
            output_file = os.path.join(args.output_directory, 
                                      f"{args.account_name}-{args.compliance}-{timestamp}")
        
        prowler.generate_report(findings, format_type, output_file)
    
    # Print summary
    summary = prowler._count_by_severity(findings)
    print(f"\nSecurity Assessment Summary for {args.account_name}:")
    print("=" * 50)
    for severity, count in summary.items():
        if count > 0:
            print(f"{severity:>12}: {count:>3} findings")
    print(f"{'TOTAL':>12}: {len(findings):>3} findings")

if __name__ == '__main__':
    main()
