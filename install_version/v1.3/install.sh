#!/bin/bash

VERSION=$1

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
            return 1
        fi
    done
    return 0
}

create_system_user() {
    log_info "Creating system user 'ddns-system'..."
    if ! id "ddns-system" &>/dev/null; then
        sudo useradd -r -d $1 -c "User for the DDNS Porkbun script" ddns-system
        sudo chown -R ddns-system:ddns-system "$1"
        log_success "User 'ddns-system' created successfully."
    else
        log_warning "User 'ddns-system' already exists."
    fi
}

setup_systemd_timer() {
    read -p "Do you want to create a systemd timer for this script? (yes/no): " create_timer
    if [[ "$create_timer" != "yes" ]]; then
        return
    fi

    systemd_service="/etc/systemd/system/ddns-porkbun.service"
    systemd_timer="/etc/systemd/system/ddns-porkbun.timer"

        # Check if the service file already exists
    if [ -f "$systemd_service" ]; then
        log_warning "The systemd service file '$systemd_service' already exists."
        read -p "Do you want to overwrite it? (yes/no): " overwrite_service
        if [[ "$overwrite_service" != "yes" ]]; then
            log_info "Skipping creation of the systemd service file."
            return
        fi
    fi

    # Check if the timer file already exists
    if [ -f "$systemd_timer" ]; then
        log_warning "The systemd timer file '$systemd_timer' already exists."
        read -p "Do you want to overwrite it? (yes/no): " overwrite_timer
        if [[ "$overwrite_timer" != "yes" ]]; then
            log_info "Skipping creation of the systemd timer file."
            return
        fi
    fi

    read -p "Enter the execution interval (e.g., '15min' or '1h'): " timer_interval

    log_info "Creating systemd service and timer..."

    sudo bash -c "cat > $systemd_service <<EOF
[Unit]
Description=DDNS Porkbun Update Service
After=network.target

[Service]
User=ddns-system
ExecStart=$1/ddns-porkbun-script.sh

[Install]
WantedBy=multi-user.target
EOF"

    sudo bash -c "cat > $systemd_timer <<EOF
[Unit]
Description=Run DDNS Porkbun script every $timer_interval

[Timer]
OnBootSec=5min
OnUnitActiveSec=$timer_interval
Unit=ddns-porkbun.service

[Install]
WantedBy=timers.target
EOF"

    sudo systemctl daemon-reload
    sudo systemctl enable --now ddns-porkbun.timer
    log_success "Systemd timer set to run every $timer_interval."
}

main() {
    if [ -z "$VERSION" ]; then
        log_error "Version not provided. Exiting."
        exit 1
    fi
    
    log_success "Installing ddns-porkbun-script version $VERSION..."

    if ! check_dependencies; then
        exit 1
    fi

    # Define the installation directory as the 'ddns-porkbun-script' folder in the opt directory
    install_dir="/opt/ddns-porkbun-script"

    # Create the directory if it doesn't exist
    if [ ! -d "$install_dir" ]; then
        log_info "Creating directory: $install_dir"
        sudo mkdir -p "$install_dir"
    fi

    # Download the specific version's tar.gz file
    url="https://github.com/StafLoker/ddns-porkbun-script/archive/refs/tags/${VERSION}.tar.gz"
    log_info "Downloading version ${VERSION} from $url"
    sudo wget --progress=dot:giga --no-check-certificate -P "${install_dir}" "${url}" || {
        log_error "Download failed. Retrying..."
        sudo wget --progress=dot:giga --no-check-certificate -P "${install_dir}" "${url}" || exit 1
    }

    # Check if the download was successful
    if [[ $? -ne 0 ]]; then
        log_error "Failed to download ddns-porkbun-script version $VERSION. Please check if the version exists."
        exit 1
    fi

    log_info "Extracting the downloaded tar.gz file..."
    # Extract the downloaded tar.gz file into the installation directory
    sudo tar -xzvf "${install_dir}/${VERSION}.tar.gz" -C "$install_dir"
    sudo rm -f "${install_dir}/${VERSION}.tar.gz"

    # Move the extracted files to the correct location
    if [ -f "${install_dir}/ddns-porkbun-script-${VERSION#v}/ddns-porkbun-script.sh" ] &&
        [ -f "${install_dir}/ddns-porkbun-script-${VERSION#v}/LICENSE" ] &&
        [ -f "${install_dir}/ddns-porkbun-script-${VERSION#v}/README.md" ]; then
        sudo mv "${install_dir}/ddns-porkbun-script-${VERSION#v}/ddns-porkbun-script.sh" \
            "${install_dir}/ddns-porkbun-script-${VERSION#v}/LICENSE" \
            "${install_dir}/ddns-porkbun-script-${VERSION#v}/README.md" \
            "$install_dir/"
    else
        log_error "One or more files are missing in the source directory."
        exit 1
    fi
    sudo rm -rf "${install_dir}/ddns-porkbun-script-${VERSION#v}"

    log_info "Checking for keys.env file..."
    if [ ! -f "${install_dir}/keys.env" ]; then
        log_info "- Creating keys.env file..."
        read -p "Enter your Porkbun API key: " api_key
        read -p "Enter your Porkbun secret API key: " secret_api_key
        sudo bash -c "cat > ${install_dir}/keys.env <<EOF
PORKBUN_API_KEY=\"${api_key}\"
PORKBUN_SECRET_API_KEY=\"${secret_api_key}\"
EOF"
        sudo chmod 600 "${install_dir}/keys.env"
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

        sudo bash -c "jq -n \
        --arg domain '$domain' \
        --argjson concurrency '$concurrency_value' \
        --argjson ipv4 '$ipv4_value' \
        --argjson subdomains_a '$subdomains_type_a_json' \
        --argjson ipv6 '$ipv6_value' \
        --argjson subdomains_aaaa '$subdomains_type_aaaa_json' \
        '{domain: \$domain, concurrency: \$concurrency, ipv4: \$ipv4, subdomains_type_a: \$subdomains_a, ipv6: \$ipv6, subdomains_type_aaaa: \$subdomains_aaaa}' \
        > '$install_dir/data.json'"

    else
        log_success "data.json file already exists."
    fi

    # Modify the ddns-porkbun-script.sh file to use absolute paths for keys.env and data.json
    log_info "Updating ddns-porkbun-script.sh to use absolute paths for keys.env and data.json"

    # Update the keys.env source line to use the absolute path
    sudo sed -i "s|source keys.env|source $install_dir/keys.env|" "${install_dir}/ddns-porkbun-script.sh"

    # Update the DATA_FILE absolute path in ddns-porkbun-script.sh
    sudo sed -i "s|readonly DATA_FILE=\"data.json\"|readonly DATA_FILE=\"$install_dir/data.json\"|" "${install_dir}/ddns-porkbun-script.sh"

    log_success "ddns-porkbun-script.sh has been updated to use absolute paths for keys.env and data.json."

    log_info "Making the main script executable..."
    # Make the main script executable
    sudo chmod +x "${install_dir}/ddns-porkbun-script.sh"

    create_system_user $install_dir
    setup_systemd_timer $install_dir

    log_success "Installation or update of ddns-porkbun-script version $VERSION completed successfully!"
}

main
