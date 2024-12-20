#!/bin/bash

# Load keys
source keys.env

# Load JSON data file
readonly DATA_FILE="data.json"
readonly DOMAIN=$(jq -r '.domain' "$DATA_FILE")
readonly SUBDOMAINS=$(jq -r '.subdomains[]' "$DATA_FILE")

# Check if API keys are set
if [[ -z "$PORKBUN_API_KEY" || -z "$PORKBUN_SECRET_API_KEY" ]]; then
  echo "ERROR: API keys are not set. Exiting."
  exit 1
fi

# Check if DATA_FILE exists
if [[ ! -f "$DATA_FILE" ]]; then
  echo "ERROR: Data file $DATA_FILE not found. Exiting."
  exit 1
fi

# Porkbun API URLs
readonly BASE_URL="https://api.porkbun.com/api/json/v3"
readonly GET_IP_URL="https://api.ipify.org"
readonly RETRIEVE_RECORD_URL="$BASE_URL/dns/retrieveByNameType/$DOMAIN/A"
readonly UPDATE_RECORD_URL="$BASE_URL/dns/editByNameType/$DOMAIN/A"

# Function to log messages with timestamp
log() {
  local level=$1 message=$2
  case "$level" in
  DEBUG) syslog_level="debug" ;; INFO) syslog_level="info" ;;
  WARNING) syslog_level="warning" ;; ERROR) syslog_level="err" ;;
  *) syslog_level="notice" ;; # Default level
  esac
  logger -p user.$syslog_level -t ddns-porkbun "$message"
}

# Function to get the public IP
get_public_ip() {
  curl -s "$GET_IP_URL" || return 1
}

# Function to retrieve the current IP for a subdomain
get_current_ip() {
  local subdomain=$1
  response=$(curl -s "$RETRIEVE_RECORD_URL/$subdomain" \
    -H "Content-Type: application/json" \
    -d "{\"apikey\":\"$PORKBUN_API_KEY\",\"secretapikey\":\"$PORKBUN_SECRET_API_KEY\"}")
  echo "$response" | jq -r '.records[0].content' || return 2
}

# Function to update the DDNS record
update_ddns_record() {
  local subdomain=$1 ip=$2
  response=$(curl -s -X POST "$UPDATE_RECORD_URL/$subdomain" \
    -H "Content-Type: application/json" \
    -d "{\"apikey\":\"$PORKBUN_API_KEY\",\"secretapikey\":\"$PORKBUN_SECRET_API_KEY\",\"content\":\"$ip\"}")
  echo "$response" | jq -r '.status' || return 2
}

# Function to handle subdomain update if needed
update_subdomain_if_needed() {
  local subdomain=$1 public_ip=$2

  log "INFO" "Checking subdomain: $subdomain"
  current_ip=$(get_current_ip "$subdomain") || {
    log "ERROR" "Failed to retrieve current IP for $subdomain"
    return 1
  }

  if [[ "$current_ip" != "$public_ip" ]]; then
    log "INFO" "Current IP ($current_ip) differs from public IP ($public_ip). Updating..."
    response=$(update_ddns_record "$subdomain" "$public_ip") || {
      log "ERROR" "Error updating DDNS record for $subdomain"
      return 2
    }

    if [[ "$response" == "SUCCESS" ]]; then
      log "INFO" "Record successfully updated for $subdomain with IP $public_ip"
    else
      log "ERROR" "API responded with an unexpected status: $response"
      return 3
    fi
  else
    log "INFO" "No changes in IP for $subdomain. Skipping update."
  fi
}

# Main function
main() {
  log "WARNING" "Starting DDNS update script"
  public_ip=$(get_public_ip) || {
    log "ERROR" "Failed to retrieve public IP. Exiting."
    exit 1
  }
  log "INFO" "Public IP retrieved: $public_ip"

  # Handle each subdomain in parallel
  for subdomain in $SUBDOMAINS; do
    (
      update_subdomain_if_needed "$subdomain" "$public_ip" || {
        log "ERROR" "Error processing subdomain $subdomain"
      }
    ) &
  done

  wait
  log "INFO" "All subdomains processed. Script completed."
}

# Entry point
main
