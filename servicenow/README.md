
# ServiceNow API Integration with SAS

## Overview
This is a reference implementation demonstrating how to authenticate with and query the ServiceNow API using SAS. The solution implements OAuth 2.0 authentication flows with token management and provides examples of making authenticated API calls to ServiceNow tables. 

See detailed instructions in [this SAS Communities article about using SAS with ServiceNow](https://communities.sas.com/t5/SAS-Communities-Library/How-to-use-SAS-to-work-with-ServiceNow-APIs/ta-p/983715).

## Key Features
- **OAuth 2.0 Authentication**: Implements the password grant flow for initial authentication
- **Token Refresh**: Automatically refreshes access tokens using refresh tokens without requiring credentials
- **Secure Credential Management**: Stores credentials in a secure external location
- **JSON Parsing**: Parses ServiceNow API responses and extracts data for analysis
- **Reusable Macros**: Provides macro functions for token acquisition and refresh operations
- **Sample Query**: Includes example code to query the Incident table from ServiceNow

## Components
- `getSNaccessToken`: Macro to obtain initial OAuth access token using username/password
- `refreshSNaccessToken`: Macro to refresh expiring tokens using refresh token
- Sample API call demonstrating GET request to ServiceNow incident table
- Credentials management via CSV file in secure directory

## Use Cases
- Integrate ServiceNow incident data into SAS analytics workflows
- Automate data extraction from ServiceNow for reporting
- Maintain persistent connections with automatic token lifecycle management
