#!/bin/bash

# Cloudflare API endpoint
API_ENDPOINT="https://api.cloudflare.com/client/v4/accounts/67bb9d928761c6e9c14dfae038513f9d/access/logs/access_requests"

# Cloudflare API credentials
AUTH_EMAIL="benjaminwadsworth@gmail.com"
AUTH_KEY=""

# Email notification settings
RECIPIENT_EMAIL="your_email@example.com"
SUBJECT="Cloudflare Access Notification"

# Fetch access logs using curl
response=$(curl -s -X GET "$API_ENDPOINT" \
    -H "X-Auth-Email: $AUTH_EMAIL" \
    -H "X-Auth-Key: $AUTH_KEY" \
    -H "Content-Type: application/json")

# Check if the request was successful
if [[ $(echo "$response" | jq -r '.success') == "true" ]]; then
    echo "Log entries found. Details below:"
    echo "------------------------"

    # Extract relevant information from the response
    log_entries=$(echo "$response" | jq -r '.result')

    # Check if there are any log entries
    if [[ -n "$log_entries" ]]; then
    # Loop through each log entry
    for entry in $(echo "$log_entries" | jq -c '.[]'); do
        # Extract relevant information from the log entry
        action=$(echo "$entry" | jq -r '.action')
        app_domain=$(echo "$entry" | jq -r '.app_domain')
        user_email=$(echo "$entry" | jq -r '.user_email')
        created_at=$(echo "$entry" | jq -r '.created_at')
        ip_address=$(echo "$entry" | jq -r '.ip_address')
        country=$(echo "$entry" | jq -r '.country')


        # Write out the information
        echo "Action: $action"
        echo "App Domain: $app_domain"
        echo "User Email: $user_email"
        echo "Created At: $created_at"
        echo "IP Address: $ip_address"
        echo "Country: $country"
        echo "------------------------"
    done
    fi
else
    # Handle API request failure
    error_message=$(echo "$response" | jq -r '.errors[0].message')
    echo "API request failed: $error_message"
fi