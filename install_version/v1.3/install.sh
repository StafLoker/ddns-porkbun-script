#!/bin/bash

# Color Definitions
readonly RED='\033[31m'
readonly YELLOW='\033[33m'
readonly GREEN='\033[32m'
readonly PURPLE='\033[36m'
readonly RESET='\033[0m'

# Function to print INFO messages
log_info() {
    echo -e "${YELLOW}[INFO] $1${RESET}"
}

# Function to print SUCCESS messages
log_success() {
    echo -e "${GREEN}[SUCCESS] $1${RESET}"
}

# Function to print ERROR messages
log_error() {
    echo -e "${RED}[ERROR] $1${RESET}"
}

# Function to print WARNING messages
log_warning() {
    echo -e "${PURPLE}[WARNING] $1${RESET}"
}

check_dependencies() {
    for cmd in curl wget sed tar jq; do
        if ! command -v $cmd &>/dev/null; then
            log_error "$cmd is not installed. Please install it and try again."
            exit 1
        fi
    done
}

main() {
    log_success "Installing ddns-porkbun-script version $VERSION..."

    check_dependencies

    # Define the installation directory as the 'ddns-porkbun-script' folder in the user's home directory
    install_dir="$HOME/ddns-porkbun-script"

    # Create the directory if it doesn't exist
    if [ ! -d "$install_dir" ]; then
        log_info "Creating directory: $install_dir"
        mkdir -p "$install_dir"
    fi

    # Download the specific version's tar.gz file
    url="https://github.com/StafLoker/ddns-porkbun-script/archive/refs/tags/${VERSION}.tar.gz"
    log_info "Downloading version ${VERSION} from $url"
    wget --progress=dot:giga --no-check-certificate -P "${install_dir}" "${url}" || {
        log_error "Download failed. Retrying..."
        wget --progress=dot:giga --no-check-certificate -P "${install_dir}" "${url}" || exit 1
    }

    # Check if the download was successful
    if [[ $? -ne 0 ]]; then
        log_error "Failed to download ddns-porkbun-script version $VERSION. Please check if the version exists."
        exit 1
    fi

    log_info "Extracting the downloaded tar.gz file..."
    # Extract the downloaded tar.gz file into the installation directory
    tar -xzvf "${install_dir}/${VERSION}.tar.gz" -C "$install_dir"
    rm -f "${install_dir}/${VERSION}.tar.gz"

    # Move the extracted files to the correct location
    if [ -f "${install_dir}/ddns-porkbun-script-${VERSION#v}/ddns-porkbun-script.sh" ] &&
        [ -f "${install_dir}/ddns-porkbun-script-${VERSION#v}/LICENSE" ] &&
        [ -f "${install_dir}/ddns-porkbun-script-${VERSION#v}/README.md" ]; then
        mv "${install_dir}/ddns-porkbun-script-${VERSION#v}/ddns-porkbun-script.sh" \
            "${install_dir}/ddns-porkbun-script-${VERSION#v}/LICENSE" \
            "${install_dir}/ddns-porkbun-script-${VERSION#v}/README.md" \
            "$install_dir/"
    else
        log_error "One or more files are missing in the source directory."
        exit 1
    fi
    rm -rf "${install_dir}/ddns-porkbun-script-${VERSION#v}"

    log_info "Checking for keys.env file..."
    if [ ! -f "${install_dir}/keys.env" ]; then
        log_info "- Creating keys.env file..."
        read -p "Enter your Porkbun API key: " api_key
        read -p "Enter your Porkbun secret API key: " secret_api_key
        echo "PORKBUN_API_KEY=\"${api_key}\"" >"${install_dir}/keys.env"
        echo "PORKBUN_SECRET_API_KEY=\"${secret_api_key}\"" >>"${install_dir}/keys.env"
        chmod 600 "${install_dir}/keys.env"
    else
        log_success "keys.env file already exists."
    fi

    log_info "Checking for data.json file..."
    if [ ! -f "${install_dir}/data.json" ]; then
        log_info "- Creating data.json file..."

        read -p "Enter your domain (e.g., example.com): " domain

        read -p "Do you want to enable concurrency? (yes/no): " concurrency
        if [ "$concurrency" = "yes" ]; then
            concurrency_value="true"
        else
            concurrency_value="false"
        fi

        read -p "Do you want to enable to update ipv4 records? (yes/no): " ipv4
        if [ "$ipv4" = "yes" ]; then
            ipv4_value="true"
        else
            ipv4_value="false"
        fi

        subdomains_type_a_list=()
        if [[ "$ipv4_value" == "true" ]]; then
            log_info "Enter your subdomains with IPv4 one by one. Type '0' when you are finished."
            while true; do
                read -p "Enter a subdomain (or type '0' to finish): " subdomain
                if [[ "$subdomain" == "0" ]]; then
                    break
                fi
                if [[ -n "$subdomain" ]]; then
                    subdomains_type_a_list+=("$subdomain")
                fi
            done
        fi

        subdomains_type_a_json=$(printf '"%s",' "${subdomains_type_a_list[@]}")
        subdomains_type_a_json="[${subdomains_type_a_json%,}]"

        read -p "Do you want to enable to update ipv6 records? (yes/no): " ipv6
        if [ "$ipv6" = "yes" ]; then
            ipv6_value="true"
        else
            ipv6_value="false"
        fi

        subdomains_type_aaaa_list=()
        if [[ "$ipv6_value" == "true" ]]; then
            log_info "Enter your subdomains with IPv6 one by one. Type '0' when you are finished."
            while true; do
                read -p "Enter a subdomain (or type '0' to finish): " subdomain
                if [[ "$subdomain" == "0" ]]; then
                    break
                fi
                if [[ -n "$subdomain" ]]; then
                    subdomains_type_aaaa_list+=("$subdomain")
                fi
            done
        fi

        subdomains_type_aaaa_json=$(printf '"%s",' "${subdomains_type_aaaa_list[@]}")
        subdomains_type_aaaa_json="[${subdomains_type_aaaa_json%,}]"

        cat <<EOF >"${install_dir}/data.json"
{
    "domain": "${domain}",
    "concurrency": ${concurrency_value},
    "ipv4": ${ipv4_value},
    "subdomains_type_a": ${subdomains_type_a_json},
    "ipv6": ${ipv6_value},
    "subdomains_type_aaaa": ${subdomains_type_aaaa_json}
}
EOF

    else
        log_success "data.json file already exists."
    fi

    # Modify the ddns-porkbun-script.sh file to use absolute paths for keys.env and data.json
    log_info "Updating ddns-porkbun-script.sh to use absolute paths for keys.env and data.json"

    # Update the keys.env source line to use the absolute path
    sed -i "s|source keys.env|source $install_dir/keys.env|" "${install_dir}/ddns-porkbun-script.sh"

    # Update the DATA_FILE absolute path in ddns-porkbun-script.sh
    sed -i "s|readonly DATA_FILE=\"data.json\"|readonly DATA_FILE=\"$install_dir/data.json\"|" "${install_dir}/ddns-porkbun-script.sh"

    log_success "ddns-porkbun-script.sh has been updated to use absolute paths for keys.env and data.json."

    log_info "Making the main script executable..."
    # Make the main script executable
    chmod +x "${install_dir}/ddns-porkbun-script.sh"

    log_success "Installation or update of ddns-porkbun-script version $VERSION completed successfully!"
}

main
