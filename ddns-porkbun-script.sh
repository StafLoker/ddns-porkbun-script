#!/bin/bash

# Load keys
source keys.env

# Load JSON data file
DATA_FILE="data.json"
DOMAIN=$(jq -r '.domain' "$DATA_FILE")
SUBDOMAINS=$(jq -r '.subdomains[]' "$DATA_FILE")

# Porkbun API URLs
BASE_URL="https://api.porkbun.com/api/json/v3"
GET_IP_URL="https://api.ipify.org"
RETRIEVE_RECORD_URL="$BASE_URL/dns/retrieveByNameType/$DOMAIN/A"
UPDATE_RECORD_URL="$BASE_URL/dns/editByNameType/$DOMAIN/A"

# Function to log messages with timestamp
log() {
  local level=$1
  local message=$2
  case "$level" in
    DEBUG) syslog_level="debug" ;;
    INFO) syslog_level="info" ;;
    WARNING) syslog_level="warning" ;;
    ERROR) syslog_level="err" ;;
    *) syslog_level="notice" ;;  # Default level
  esac
  logger -p user.$syslog_level -t ddns-porkbun "$message"
}

# Function to get the public IP
get_public_ip() {
  curl -s "$GET_IP_URL"
}

# Function to retrieve the current IP for a subdomain
get_current_ip() {
  local subdomain=$1
  response=$(curl -s "$RETRIEVE_RECORD_URL/$subdomain" \
    -H "Content-Type: application/json" \
    -d "{\"apikey\":\"$PORKBUN_API_KEY\",\"secretapikey\":\"$PORKBUN_SECRET_API_KEY\"}")
  echo "$response" | jq -r '.records[0].content'
}

# Function to update the DDNS record
update_ddns_record() {
  local subdomain=$1
  local ip=$2
  response=$(curl -s -X POST "$UPDATE_RECORD_URL/$subdomain" \
    -H "Content-Type: application/json" \
    -d "{\"apikey\":\"$PORKBUN_API_KEY\",\"secretapikey\":\"$PORKBUN_SECRET_API_KEY\",\"content\":\"$ip\"}")
  echo "$response" | jq -r '.status'
}

# Main script execution
log "WARNING" "Starting DDNS update script"

public_ip=$(get_public_ip)
if [ -z "$public_ip" ]; then
  log "ERROR" "Could not retrieve public IP."
  exit 1
fi

log "INFO" "Current public IP: $public_ip"

for subdomain in $SUBDOMAINS; do
  log "INFO" "Processing subdomain: $subdomain"

  current_ip=$(get_current_ip "$subdomain")
  log "INFO" "Current IP for $subdomain: $current_ip"

  if [[ "$current_ip" != "null" && "$current_ip" != "" ]]; then
    if [[ "$current_ip" != "$public_ip" ]]; then
      log "INFO" "IP has changed for $subdomain. Updating record..."
      status=$(update_ddns_record "$subdomain" "$public_ip")
      if [[ "$status" == "SUCCESS" ]]; then
        log "INFO" "Record successfully updated for $subdomain to $public_ip"
      else
        log "ERROR" "Error updating record for $subdomain: $status"
      fi
    else
      log "INFO" "No change in IP for $subdomain. Skipping update."
    fi
  else
    log "ERROR" "Current IP is null or blank for $subdomain. Cannot proceed with update."
  fi
done

log "INFO" "Finish DDNS update script"
