from flask import Flask, render_template, request, jsonify
import pandas as pd
import glob
import os
import json
from datetime import datetime

app = Flask(__name__)

# Load CSV files - check multiple patterns including Prowler reports
CSV_PATH_PATTERN1 = '/output/*/csv/*.csv'  # Original pattern
CSV_PATH_PATTERN2 = '/output/csv/*.csv'    # Direct csv folder pattern
CSV_PATH_PATTERN3 = '/output/*/prowler/reports/*.csv'  # Prowler CSV reports
JSON_PATH_PATTERN = '/output/*/prowler/reports/*.json'  # Prowler JSON reports

def load_prowler_json_data():
    """Load and parse Prowler JSON reports"""
    json_files = glob.glob(JSON_PATH_PATTERN)
    if not json_files:
        return pd.DataFrame()
    
    all_findings = []
    
    for json_file in json_files:
        try:
            with open(json_file, 'r') as f:
                data = json.load(f)
            
            # Extract metadata
            account_name = data.get('account_name', 'unknown')
            region = data.get('region', 'unknown')
            assessment_date = data.get('assessment_date', '')
            tool = data.get('tool', 'prowler')
            findings = data.get('findings', [])
            
            # If no findings, create a placeholder record so account appears in dashboard
            if not findings:
                # Extract framework from filename
                filename = os.path.basename(json_file)
                framework_part = filename.split('-')[2:-1] if '-' in filename else ['unknown']
                framework = '-'.join(framework_part).replace('_aws', '') if framework_part else 'unknown'
                
                finding_data = {
                    'Account': account_name,
                    'Region': region,
                    'CheckId': 'no-findings',
                    'Title': f'No security findings detected - {framework.upper()}',
                    'Severity': 'INFO',
                    'Status': 'PASS',
                    'ResourceId': f'{account_name}-summary',
                    'ResourceType': 'AccountSummary',
                    'Description': f'No security issues found in {framework} assessment',
                    'Framework': framework.upper(),
                    'AssessmentDate': assessment_date,
                    'Tool': tool,
                    'FileName': os.path.basename(json_file)
                }
                all_findings.append(finding_data)
            else:
                # Process actual findings
                for finding in findings:
                    finding_data = {
                        'Account': account_name,
                        'Region': finding.get('region', region),
                        'CheckId': finding.get('check_id', ''),
                        'Title': finding.get('check_title', ''),
                        'Severity': finding.get('severity', ''),
                        'Status': finding.get('status', ''),
                        'ResourceId': finding.get('resource_id', ''),
                        'ResourceType': finding.get('resource_type', ''),
                        'Description': finding.get('status_extended', ''),
                        'Framework': finding.get('compliance_framework', ''),
                        'AssessmentDate': assessment_date,
                        'Tool': tool,
                        'FileName': os.path.basename(json_file)
                    }
                    all_findings.append(finding_data)
        
        except Exception as e:
            print(f"Error reading JSON file {json_file}: {e}")
            continue
    
    if not all_findings:
        return pd.DataFrame()
    
    return pd.DataFrame(all_findings)

def load_prowler_csv_data():
    """Load and parse Prowler CSV reports"""
    csv_files = glob.glob(CSV_PATH_PATTERN3)
    if not csv_files:
        return pd.DataFrame()
    
    li = []
    
    for csv_file in csv_files:
        try:
            df = pd.read_csv(csv_file, index_col=None, header=0)
            
            # Extract account name from filename
            basename = os.path.basename(csv_file)
            account_name = basename.split('-')[0] if '-' in basename else 'unknown'
            
            # Standardize column names to match our schema
            column_mapping = {
                'CheckId': 'CheckId',
                'Severity': 'Severity', 
                'Title': 'Title',
                'ResourceId': 'ResourceId',
                'Region': 'Region',
                'Status': 'Status',
                'Description': 'Description',
                'Framework': 'Framework'
            }
            
            # Rename columns if they exist
            for old_col, new_col in column_mapping.items():
                if old_col in df.columns:
                    df = df.rename(columns={old_col: new_col})
            
            # Add metadata
            df['Account'] = account_name
            df['Tool'] = 'prowler'
            df['FileName'] = basename
            
            # Map ResourceType if not present
            if 'ResourceType' not in df.columns:
                df['ResourceType'] = 'Unknown'
            
            li.append(df)
        
        except Exception as e:
            print(f"Error reading CSV file {csv_file}: {e}")
            continue
    
    if not li:
        return pd.DataFrame()
    
    return pd.concat(li, axis=0, ignore_index=True)

def load_all_data():
    """Load all data from various sources (Security Hub + Prowler)"""
    dataframes = []
    
    # Load original Security Hub CSV files
    all_files = glob.glob(CSV_PATH_PATTERN1) + glob.glob(CSV_PATH_PATTERN2)
    for filename in all_files:
        try:
            df = pd.read_csv(filename, index_col=None, header=0)
            # Extract account name from file path or filename
            path_parts = filename.split(os.sep)
            if len(path_parts) >= 3 and path_parts[-3] != 'output':
                account_name = path_parts[-3]
            else:
                basename = os.path.basename(filename)
                if 'account' in basename.lower():
                    parts = basename.split('-')
                    for i, part in enumerate(parts):
                        if 'account' in part.lower():
                            account_name = part
                            break
                    else:
                        account_name = 'unknown'
                else:
                    account_name = 'unknown'
            df['Account'] = account_name
            df['FileName'] = os.path.basename(filename)
            df['Source'] = 'SecurityHub'
            dataframes.append(df)
        except Exception as e:
            print(f"Error reading {filename}: {e}")
            continue
    
    # Load Prowler JSON data
    prowler_json_df = load_prowler_json_data()
    if not prowler_json_df.empty:
        prowler_json_df['Source'] = 'Prowler-JSON'
        dataframes.append(prowler_json_df)
    
    # Load Prowler CSV data
    prowler_csv_df = load_prowler_csv_data()
    if not prowler_csv_df.empty:
        prowler_csv_df['Source'] = 'Prowler-CSV'
        dataframes.append(prowler_csv_df)
    
    if not dataframes:
        return pd.DataFrame()
    
    # Combine all dataframes
    combined_df = pd.concat(dataframes, axis=0, ignore_index=True, sort=False)
    return combined_df

def load_data():
    """Maintain backward compatibility - loads all data"""
    return load_all_data()

@app.route('/')
def index():
    """Main dashboard page"""
    df = load_data()
    
    if df.empty:
        return render_template('index.html', 
                               error="No CSV files found. Please run the AWS Security Hub export first.",
                               stats={})
    
    # Generate summary statistics
    stats = {
        'total_findings': len(df),
        'critical': len(df[df['Severity'] == 'CRITICAL']) if 'Severity' in df.columns else 0,
        'high': len(df[df['Severity'] == 'HIGH']) if 'Severity' in df.columns else 0,
        'medium': len(df[df['Severity'] == 'MEDIUM']) if 'Severity' in df.columns else 0,
        'low': len(df[df['Severity'] == 'LOW']) if 'Severity' in df.columns else 0,
        'accounts': df['Account'].nunique() if 'Account' in df.columns else 0,
        'failed_compliance': len(df[df['ComplianceStatus'] == 'FAILED']) if 'ComplianceStatus' in df.columns else 0
    }
    
    # Get severity distribution
    severity_dist = df['Severity'].value_counts().to_dict() if 'Severity' in df.columns else {}
    
    # Get account distribution
    account_dist = df['Account'].value_counts().to_dict() if 'Account' in df.columns else {}
    
    # Get resource type distribution
    resource_dist = df['ResourceType'].value_counts().head(10).to_dict() if 'ResourceType' in df.columns else {}
    
    # Convert DataFrame to HTML with styling
    table_html = df.to_html(
        classes='table table-striped table-hover table-sm',
        table_id='findings-table',
        escape=False,
        index=False
    )
    
    return render_template('index.html', 
                           table_html=table_html, 
                           stats=stats,
                           severity_dist=severity_dist,
                           account_dist=account_dist,
                           resource_dist=resource_dist,
                           total_files=len(glob.glob(CSV_PATH_PATTERN1) + glob.glob(CSV_PATH_PATTERN2)))

@app.route('/api/data')
def api_data():
    """API endpoint to get data as JSON"""
    df = load_data()
    if df.empty:
        return jsonify({'error': 'No data found'})
    
    return jsonify(df.to_dict('records'))

@app.route('/filter')
def filter_data():
    """Filter data based on query parameters"""
    df = load_data()
    if df.empty:
        return render_template('index.html', error="No data available")
    
    # Get filter parameters
    severity = request.args.get('severity')
    account = request.args.get('account')
    compliance = request.args.get('compliance')
    
    # Apply filters
    if severity and severity != 'ALL':
        df = df[df['Severity'] == severity]
    
    if account and account != 'ALL':
        df = df[df['Account'] == account]
    
    if compliance and compliance != 'ALL':
        df = df[df['ComplianceStatus'] == compliance]
    
    # Convert to HTML
    table_html = df.to_html(
        classes='table table-striped table-hover table-sm',
        table_id='findings-table',
        escape=False,
        index=False
    )
    
    return render_template('filtered.html', 
                           table_html=table_html, 
                           count=len(df))

@app.route('/prowler')
def prowler_dashboard():
    """Prowler-specific dashboard"""
    # Load only Prowler data
    prowler_json_df = load_prowler_json_data()
    prowler_csv_df = load_prowler_csv_data()
    
    dataframes = []
    if not prowler_json_df.empty:
        prowler_json_df['Source'] = 'JSON Report'
        dataframes.append(prowler_json_df)
    
    if not prowler_csv_df.empty:
        prowler_csv_df['Source'] = 'CSV Report'
        dataframes.append(prowler_csv_df)
    
    if not dataframes:
        return render_template('prowler.html', 
                               error="No Prowler reports found. Please run a Prowler assessment first.",
                               stats={})
    
    df = pd.concat(dataframes, axis=0, ignore_index=True, sort=False)
    
    # Generate Prowler-specific statistics
    stats = {
        'total_findings': len(df),
        'critical': len(df[df['Severity'] == 'CRITICAL']) if 'Severity' in df.columns else 0,
        'high': len(df[df['Severity'] == 'HIGH']) if 'Severity' in df.columns else 0,
        'medium': len(df[df['Severity'] == 'MEDIUM']) if 'Severity' in df.columns else 0,
        'low': len(df[df['Severity'] == 'LOW']) if 'Severity' in df.columns else 0,
        'failed': len(df[df['Status'] == 'FAIL']) if 'Status' in df.columns else 0,
        'passed': len(df[df['Status'] == 'PASS']) if 'Status' in df.columns else 0,
        'accounts': df['Account'].nunique() if 'Account' in df.columns else 0,
        'frameworks': df['Framework'].nunique() if 'Framework' in df.columns else 0,
        'json_reports': len(glob.glob(JSON_PATH_PATTERN)),
        'csv_reports': len(glob.glob(CSV_PATH_PATTERN3))
    }
    
    # Get distributions
    severity_dist = df['Severity'].value_counts().to_dict() if 'Severity' in df.columns else {}
    status_dist = df['Status'].value_counts().to_dict() if 'Status' in df.columns else {}
    account_dist = df['Account'].value_counts().to_dict() if 'Account' in df.columns else {}
    framework_dist = df['Framework'].value_counts().to_dict() if 'Framework' in df.columns else {}
    source_dist = df['Source'].value_counts().to_dict() if 'Source' in df.columns else {}
    
    # Get top failing checks
    if 'Status' in df.columns:
        failed_checks = df[df['Status'] == 'FAIL']['CheckId'].value_counts().head(10).to_dict()
    else:
        failed_checks = {}
    
    # Convert DataFrame to HTML
    table_html = df.to_html(
        classes='table table-striped table-hover table-sm',
        table_id='prowler-table',
        escape=False,
        index=False
    )
    
    return render_template('prowler.html', 
                           table_html=table_html, 
                           stats=stats,
                           severity_dist=severity_dist,
                           status_dist=status_dist,
                           account_dist=account_dist,
                           framework_dist=framework_dist,
                           source_dist=source_dist,
                           failed_checks=failed_checks)

@app.route('/api/prowler')
def api_prowler_data():
    """API endpoint to get Prowler data as JSON"""
    prowler_json_df = load_prowler_json_data()
    prowler_csv_df = load_prowler_csv_data()
    
    dataframes = []
    if not prowler_json_df.empty:
        dataframes.append(prowler_json_df)
    if not prowler_csv_df.empty:
        dataframes.append(prowler_csv_df)
    
    if not dataframes:
        return jsonify({'error': 'No Prowler data found'})
    
    df = pd.concat(dataframes, axis=0, ignore_index=True, sort=False)
    return jsonify(df.to_dict('records'))

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
