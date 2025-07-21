# AWS Security Hub SOC

## Overview

This project contains tools and utilities for extracting and viewing AWS Security Hub findings across multiple accounts.

## Quick Start

### Prerequisites
- [Docker](https://www.docker.com/get-started) installed on your system

### Setup

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd aws-security-hub-soc
   ```

2. **Configure your AWS credentials:**
   - Place AWS credentials for each account in `aws-credentials/account1`, `aws-credentials/account2`, etc.

3. **Build and Run:**
   ```bash
   docker-compose up -d
   ```

4. **Access the Dashboard:**
   - Open [http://localhost:5001](http://localhost:5001) in your browser to view the findings.

### Usage

- **Export Findings:**
  You can export findings from AWS Security Hub using:
  ```bash
  docker exec aws-security-hub-account1 /aws-scripts/export-findings-csv.sh
  ```

- **View and Filter:**
  Access the Flask dashboard to view and filter findings by severity, account, and compliance status.

## Project Structure

- **docker-compose.yml:** Docker Compose configuration for all services.
- **app.py:** Python Flask application for displaying the findings.
- **Dockerfile-dashboard:** Dockerfile for the Flask app.
- **templates/:** HTML templates for the Flask dashboard.

