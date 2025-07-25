from flask import Flask, render_template, request, jsonify
import pandas as pd
import glob
import os
from datetime import datetime

app = Flask(__name__)

# Load CSV files - check both patterns
CSV_PATH_PATTERN1 = '/output/*/csv/*.csv'  # Original pattern
CSV_PATH_PATTERN2 = '/output/csv/*.csv'    # Direct csv folder pattern

def load_data():
    """Load all CSV files and combine them"""
    # Try both patterns to find CSV files
    all_files = glob.glob(CSV_PATH_PATTERN1) + glob.glob(CSV_PATH_PATTERN2)
    if not all_files:
        return pd.DataFrame()  # Return empty DataFrame if no files
    
    li = []
    for filename in all_files:
        try:
            df = pd.read_csv(filename, index_col=None, header=0)
            # Extract account name from file path or filename
            path_parts = filename.split(os.sep)
            if len(path_parts) >= 3 and path_parts[-3] != 'output':
                # Pattern: output/account/csv/file.csv
                account_name = path_parts[-3]
            else:
                # Pattern: output/csv/findings-account-date.csv
                basename = os.path.basename(filename)
                if 'account' in basename.lower():
                    # Try to extract account name from filename
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
            li.append(df)
        except Exception as e:
            print(f"Error reading {filename}: {e}")
            continue
    
    if not li:
        return pd.DataFrame()
    
    frame = pd.concat(li, axis=0, ignore_index=True)
    return frame

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

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
