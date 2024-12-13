#!/bin/bash

# Configuration


# Porkbun API URLs
BASE_URL="https://api.porkbun.com/api/json/v3"
GET_IP_URL="https://api.ipify.org" # Service to get your public IP

# Function to log messages with timestamp
log() {
  local level=$1
  local message=$2
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message"
}

# Function to get the public IP
get_public_ip() {
  curl -s "$GET_IP_URL"
}

# Function to update the DDNS record
update_ddns_record() {
  local subdomain=$1
  local ip=$2
  curl -s -X POST "$BASE_URL/dns/editByNameType/$DOMAIN/A/$subdomain" \
    -H "Content-Type: application/json" \
    -d "{\"apikey\":\"$API_KEY\",\"secretapikey\":\"$SECRET_API_KEY\",\"content\":\"$ip\"}"
}

# Main

log "WARNING" "Starting DDNS update script"

log "DEBUG" "Getting public IP..."
public_ip=$(get_public_ip)
if [ -z "$public_ip" ]; then
  log "ERROR" "Could not retrieve public IP."
  sleep $UPDATE_INTERVAL
  continue
fi

log "INFO" "Current public IP: $public_ip"

for subdomain in "${SUBDOMAINS[@]}"; do
  log "INFO" "Processing subdomain: $subdomain"

  log "INFO" "Updating DDNS record for $subdomain.$DOMAIN to IP: $public_ip..."
  response=$(update_ddns_record "$subdomain" "$public_ip")

  if [ "$response" == "{"status":"SUCCESS"}" ]; then
    log "INFO" "Record successfully updated for $subdomain to $public_ip"
  else
    log "ERROR" "Error updating record for $subdomain: $response"
  fi
done

log "INFO" "Sleeping for $UPDATE_INTERVAL seconds before next check..."