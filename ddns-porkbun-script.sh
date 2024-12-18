#!/bin/bash

# Load keys
source keys.env

# Load JSON
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
  *) syslog_level="notice" ;; # Nivel por defecto
  esac
  logger -p user.$syslog_level -t ddns-porkbun "$message"
}

# Function to get the public IP
get_public_ip() {
  curl -s "$GET_IP_URL"
}

# Function to retrieve the current IP for the subdomain
get_current_ip() {
  local subdomain=$1
  response=$(curl -s "$RETRIEVE_RECORD_URL/$subdomain")
  response=$(curl -s -X POST "$RETRIEVE_RECORD_URL/$subdomain" \
    -H "Content-Type: application/json" \
    -d "{\"apikey\":\"$PORKBUN_API_KEY\",\"secretapikey\":\"$PORKBUN_SECRET_API_KEY\"}")
  # Extract the current IP from the response JSON
  current_ip=$(echo "$response" | jq -r '.records[0].content')
  echo "$current_ip"
}

# Function to update the DDNS record
update_ddns_record() {
  local subdomain=$1
  local ip=$2
  response=$(curl -s -X POST "$UPDATE_RECORD_URL/$subdomain" \
    -H "Content-Type: application/json" \
    -d "{\"apikey\":\"$PORKBUN_API_KEY\",\"secretapikey\":\"$PORKBUN_SECRET_API_KEY\",\"content\":\"$ip\"}")

  # Extract only the status value from the response
  status=$(echo "$response" | jq -r '.status')
  echo "$status"
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

for subdomain in $SUBDOMAINS; do
  log "INFO" "Processing subdomain: $subdomain"

  # Get the current IP for the subdomain
  current_ip=$(get_current_ip "$subdomain")

  log "INFO" "Current IP for $subdomain: $current_ip"

  # Check if the current IP of subdomain is not null or blank
  if [[ "$current_ip" != "null" && "$current_ip" != "" ]]; then
    # Check if the current IP is different from the public IP
    if [[ "$current_ip" != "$public_ip" ]]; then
      log "INFO" "IP has changed for $subdomain. Updating record..."
      response=$(update_ddns_record "$subdomain" "$public_ip")

      # Check if the update was successful
      if [[ "$response" == "SUCCESS" ]]; then
        log "INFO" "Record successfully updated for $subdomain to $public_ip"
      else
        log "ERROR" "Error updating record for $subdomain: $response"
      fi
    else
      log "INFO" "No change in IP for $subdomain. Skipping update."
    fi
  else
    log "ERROR" "Current IP is null or blank for $subdomain. Cannot proceed with update."
  fi
done

log "INFO" "Finish DDNS update script"
