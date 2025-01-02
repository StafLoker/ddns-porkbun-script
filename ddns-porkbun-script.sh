#!/bin/bash

# Load keys
source keys.env

readonly DATA_FILE="data.json"

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

# Load JSON data file
readonly DOMAIN=$(jq -r '.domain' "$DATA_FILE")
readonly CONCURRENCY=$(jq -r '.concurrency' "$DATA_FILE")
readonly IPv4=$(jq -r '.ipv4' "$DATA_FILE")
readonly SUBDOMAINS_TYPE_A=$(jq -r '.subdomains_type_a[]' "$DATA_FILE")
readonly IPv6=$(jq -r '.ipv6' "$DATA_FILE")
readonly SUBDOMAINS_TYPE_AAAA=$(jq -r '.subdomains_type_aaaa[]' "$DATA_FILE")

# Porkbun API URLs
readonly BASE_URL="https://api.porkbun.com/api/json/v3"
readonly GET_IPv4_URL="https://api.ipify.org"
readonly GET_IPv6_URL="https://api6.ipify.org"
readonly RETRIEVE_RECORD_URL="$BASE_URL/dns/retrieveByNameType/$DOMAIN"
readonly UPDATE_RECORD_URL="$BASE_URL/dns/editByNameType/$DOMAIN"

# Function to log messages
log() {
  local level=$1 message=$2
  case "$level" in
  DEBUG) syslog_level="debug" ;; INFO) syslog_level="info" ;;
  WARNING) syslog_level="warning" ;; ERROR) syslog_level="err" ;;
  *) syslog_level="notice" ;; # Default level
  esac
  logger -p user.$syslog_level -t ddns-porkbun "$message"
}

# Function to get the public IPv4
get_public_ipv4() {
  curl -s "$GET_IPv4_URL" || return 1
}

# Function to get the public IPv6
get_public_ipv6() {
  curl -s "$GET_IPv6_URL" || return 1
}

# Function to retrieve the current IP for a subdomain
get_current_ip_dns_record() {
  local subdomain=$1 type=$2
  response=$(curl -s -X POST "$RETRIEVE_RECORD_URL/$type/$subdomain" \
    -H "Content-Type: application/json" \
    -d "{\"apikey\":\"$PORKBUN_API_KEY\",\"secretapikey\":\"$PORKBUN_SECRET_API_KEY\"}")
  echo "$response" | jq -r '.records[0].content' || return 2
}

# Function to update the DNS record
update_dns_record() {
  local subdomain=$1 ip=$2 type=$3
  response=$(curl -s -X POST "$UPDATE_RECORD_URL/$type/$subdomain" \
    -H "Content-Type: application/json" \
    -d "{\"apikey\":\"$PORKBUN_API_KEY\",\"secretapikey\":\"$PORKBUN_SECRET_API_KEY\",\"content\":\"$ip\"}")
  echo "$response" | jq -r '.status' || return 2
}

# Function to handle subdomain update if needed
update_subdomain_if_needed() {
  local subdomain=$1 public_ip=$2 type=$3

  log "INFO" "Checking subdomain: $subdomain"
  current_ip=$(get_current_ip_dns_record "$subdomain" "$type") || {
    log "ERROR" "Failed to retrieve current IP for $subdomain"
    return 1
  }

  if [[ "$current_ip" != "$public_ip" ]]; then
    log "INFO" "Current IP ($current_ip) differs from public IP ($public_ip). Updating..."
    response=$(update_dns_record "$subdomain" "$public_ip" "$type") || {
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

  if [[ "$IPv4" == "true" ]]; then
    public_ipv4=$(get_public_ipv4) || {
      log "ERROR" "Failed to retrieve public IPv4. Exiting."
      exit 1
    }
    log "INFO" "Public IPv4 retrieved: $public_ipv4"
  else
    log "INFO" "No update IPv4 subdomains."
  fi

  if [[ "$IPv6" == "true" ]]; then
    public_ipv6=$(get_public_ipv6) || {
      log "ERROR" "Failed to retrieve public IPv6. Exiting."
      exit 2
    }
    log "INFO" "Public IPv6 retrieved: $public_ipv6"
  else
    log "INFO" "No update IPv6 subdomains."
  fi

  if [[ "$IPv4" == "false" && "$IPv6" == "false" ]]; then
    log "ERROR" "Neither IPv4 nor IPv6 are enabled for updates. Exiting."
    exit 3
  fi

  if [[ "$CONCURRENCY" == "true" ]]; then
    # Handle each subdomain in parallel
    if [[ "$IPv4" == "true" ]]; then
      for subdomain in $SUBDOMAINS_TYPE_A; do
        (
          update_subdomain_if_needed "$subdomain" "$public_ipv4" "A" || {
            log "ERROR" "Error processing subdomain $subdomain with IPv4."
          }
        ) &
      done
      wait # Wait for all background tasks to finish
      log "INFO" "All subdomains processed with IPv4."
    fi

    if [[ "$IPv6" == "true" ]]; then
      for subdomain in $SUBDOMAINS_TYPE_AAAA; do
        (
          update_subdomain_if_needed "$subdomain" "$public_ipv6" "A" || {
            log "ERROR" "Error processing subdomain $subdomain with IPv6."
          }
        ) &
      done
      wait # Wait for all background tasks to finish
      log "INFO" "All subdomains processed with IPv6."
    fi
  else
    # Handle each subdomain sequentially
    if [[ "$IPv4" == "true" ]]; then
      for subdomain in $SUBDOMAINS_TYPE_A; do
        update_subdomain_if_needed "$subdomain" "$public_ipv4" "A" || {
          log "ERROR" "Error processing subdomain $subdomain with IPv4."
        }
      done
      log "INFO" "All subdomains processed with IPv4."
    fi

    if [[ "$IPv6" == "true" ]]; then
      for subdomain in $SUBDOMAINS_TYPE_AAAA; do
        update_subdomain_if_needed "$subdomain" "$public_ipv6" "AAAA" || {
          log "ERROR" "Error processing subdomain $subdomain with IPv6."
        }
      done
      log "INFO" "All subdomains processed with IPv6."
    fi
  fi

  log "INFO" "All subdomains processed. Script completed."
}

# Entry point
main
