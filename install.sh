#!/bin/bash

# DDNS Porkbun Installer Script
# Repository: https://github.com/StafLoker/ddns-porkbun-script
# Usage: bash <(curl -Ls "https://raw.githubusercontent.com/StafLoker/ddns-porkbun-script/main/install.sh")

set -euo pipefail

# Color Definitions
readonly RED='\033[31m'
readonly YELLOW='\033[33m'
readonly GREEN='\033[32m'
readonly PURPLE='\033[36m'
readonly BLUE='\033[34m'
readonly RESET='\033[0m'

# Configuration
readonly CONFIG_FILE="/etc/ddns-porkbun/config.yaml"
readonly CONFIG_DIR="/etc/ddns-porkbun"
readonly LOG_FILE="/var/log/ddns-porkbun.log"
readonly SERVICE_NAME="ddns-porkbun"
readonly INSTALL_DIR="/opt/ddns-porkbun"
readonly SCRIPT_NAME="ddns-porkbun-script.sh"
readonly ENV_FILE="/etc/ddns-porkbun/.env"

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

# Function to print DEBUG messages
log_debug() {
    echo -e "${BLUE}[DEBUG] $1${RESET}"
}

# Function to ask yes/no questions
ask_yes_no() {
    local question="$1"
    local default="${2:-n}"
    local answer

    while true; do
        if [[ "$default" == "y" ]]; then
            read -p "$question [Y/n]: " answer
            answer=${answer:-y}
        else
            read -p "$question [y/N]: " answer
            answer=${answer:-n}
        fi

        case ${answer,,} in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) log_warning "Please answer 'y' or 'n'" ;;
        esac
    done
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        log_info "Use: sudo bash <(curl -Ls \"https://raw.githubusercontent.com/StafLoker/ddns-porkbun-script/main/install.sh\")"
        exit 1
    fi
}

# Function to check and install dependencies
check_dependencies() {
    log_info "Checking dependencies..."

    local dependencies=("curl" "wget" "sed" "tar" "yq" "jq")
    local missing_deps=()

    for cmd in "${dependencies[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_warning "Missing dependencies: ${missing_deps[*]}"

        if ask_yes_no "Do you want to install missing dependencies?" "y"; then
            log_info "Installing dependencies..."
            apt-get update

            for dep in "${missing_deps[@]}"; do
                case "$dep" in
                    "yq")
                        log_info "Installing yq..."
                        wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
                        chmod +x /usr/local/bin/yq
                        ;;
                    "jq")
                        log_info "Installing jq..."
                        apt-get install -y jq
                        ;;
                    *)
                        log_info "Installing $dep..."
                        apt-get install -y "$dep"
                        ;;
                esac
            done

            log_success "Dependencies installed successfully"
        else
            log_error "Cannot continue without dependencies. Aborting installation."
            exit 1
        fi
    else
        log_success "All dependencies are installed"
    fi
}

# Function to create system user
create_system_user() {
    log_info "Creating system user 'ddns-porkbun'..."

    if ! id "ddns-porkbun" &>/dev/null; then
        useradd -r -s /bin/false -d /nonexistent -c "DDNS Porkbun service user" ddns-porkbun
        log_success "User 'ddns-porkbun' created successfully"
    else
        log_info "User 'ddns-porkbun' already exists"
    fi
}

# Function to download scripts
download_scripts() {
    log_info "Downloading scripts from repository..."

    # Get latest version from GitHub
    log_info "Fetching latest version from GitHub..."
    local VERSION
    VERSION=$(curl -Ls "https://api.github.com/repos/StafLoker/ddns-porkbun-script/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    if [[ -z "$VERSION" ]]; then
        log_error "Failed to fetch latest version. Exiting."
        exit 1
    fi

    log_info "Latest version found: $VERSION"

    # Create install directory
    mkdir -p "$INSTALL_DIR"

    # Download the specific version's tar.gz file
    local url="https://github.com/StafLoker/ddns-porkbun-script/archive/refs/tags/${VERSION}.tar.gz"
    log_info "Downloading version ${VERSION} from $url"

    wget --progress=dot:giga --no-check-certificate -P "${INSTALL_DIR}" "${url}" || {
        log_error "Download failed. Retrying..."
        wget --progress=dot:giga --no-check-certificate -P "${INSTALL_DIR}" "${url}" || {
            log_error "Failed to download after retry. Exiting."
            exit 1
        }
    }

    log_info "Extracting the downloaded tar.gz file..."
    tar -xzf "${INSTALL_DIR}/${VERSION}.tar.gz" -C "$INSTALL_DIR"
    rm -f "${INSTALL_DIR}/${VERSION}.tar.gz"

    # Move the extracted files to the correct location
    if [[ -f "${INSTALL_DIR}/ddns-porkbun-script-${VERSION#v}/ddns-porkbun-script.sh" ]]; then
        mv "${INSTALL_DIR}/ddns-porkbun-script-${VERSION#v}/"* "$INSTALL_DIR/"
        rm -rf "${INSTALL_DIR}/ddns-porkbun-script-${VERSION#v}"

        # Make script executable
        chmod +x "${INSTALL_DIR}/$SCRIPT_NAME"

        # Create symlink
        ln -sf "$INSTALL_DIR/$SCRIPT_NAME" "/usr/local/bin/$SERVICE_NAME"

        log_success "Scripts downloaded and configured"
    else
        log_error "Script file not found in the downloaded archive"
        exit 1
    fi
}

# Function to initialize config structure
init_config() {
    log_info "Initializing configuration..."

    # Create config directory
    mkdir -p "$CONFIG_DIR"

    # Set proper permissions
    chown -R ddns-porkbun:ddns-porkbun "$CONFIG_DIR"
    chmod 750 "$CONFIG_DIR"
}

# Function to configure API keys
configure_api_keys() {
    log_info "Configuring API keys..."

    if [[ ! -f "$ENV_FILE" ]]; then
        log_info "Creating .env file..."

        echo
        log_info "You need your Porkbun API credentials:"
        log_info "1. Go to https://porkbun.com/account/api"
        log_info "2. Enable API access"
        log_info "3. Get your API key and Secret API key"
        echo

        read -p "Enter your Porkbun API key: " api_key
        read -p "Enter your Porkbun secret API key: " secret_api_key

        cat > "$ENV_FILE" <<EOF
PORKBUN_API_KEY="$api_key"
PORKBUN_SECRET_API_KEY="$secret_api_key"
EOF

        # Set proper permissions
        chmod 600 "$ENV_FILE"
        chown ddns-porkbun:ddns-porkbun "$ENV_FILE"

        log_success ".env file created successfully"
    else
        log_info ".env file already exists"
    fi
}

# Function to configure DDNS settings
configure_ddns() {
    log_info "Configuring DDNS settings..."

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_info "Creating configuration file..."

        read -p "Enter your domain (e.g., example.com): " domain

        # Configure concurrency
        local concurrency_value="false"
        if ask_yes_no "Do you want to enable concurrent updates?"; then
            concurrency_value="true"
        fi

        # Configure IPv4
        local ipv4_enabled="false"
        local ipv4_subdomains=()
        if ask_yes_no "Do you want to update IPv4 records?" "y"; then
            ipv4_enabled="true"

            log_info "Enter IPv4 subdomains (one by one). Type 'done' when finished."
            while true; do
                read -p "Enter subdomain (or 'done' to finish): " subdomain
                if [[ "$subdomain" == "done" ]]; then
                    break
                fi
                if [[ -n "$subdomain" ]]; then
                    ipv4_subdomains+=("$subdomain")
                fi
            done
        fi

        # Configure IPv6
        local ipv6_enabled="false"
        local ipv6_subdomains=()
        if ask_yes_no "Do you want to update IPv6 records?"; then
            ipv6_enabled="true"

            log_info "Enter IPv6 subdomains (one by one). Type 'done' when finished."
            while true; do
                read -p "Enter subdomain (or 'done' to finish): " subdomain
                if [[ "$subdomain" == "done" ]]; then
                    break
                fi
                if [[ -n "$subdomain" ]]; then
                    ipv6_subdomains+=("$subdomain")
                fi
            done
        fi

        # Create YAML configuration
        cat > "$CONFIG_FILE" <<EOF
domain: '$domain'
concurrency: $concurrency_value
ipv4:
  enable: $ipv4_enabled
  subdomains: []
ipv6:
  enable: $ipv6_enabled
  subdomains: []
EOF

        # Add IPv4 subdomains
        for subdomain in "${ipv4_subdomains[@]}"; do
            yq eval ".ipv4.subdomains += [\"$subdomain\"]" -i "$CONFIG_FILE"
        done

        # Add IPv6 subdomains
        for subdomain in "${ipv6_subdomains[@]}"; do
            yq eval ".ipv6.subdomains += [\"$subdomain\"]" -i "$CONFIG_FILE"
        done

        # Set proper permissions
        chmod 640 "$CONFIG_FILE"
        chown ddns-porkbun:ddns-porkbun "$CONFIG_FILE"

        log_success "Configuration file created successfully"
    else
        log_info "Configuration file already exists"
    fi
}

# Function to configure logging
configure_logging() {
    log_info "Configuring logging system..."

    # Create log file with proper permissions
    touch "$LOG_FILE"
    chown ddns-porkbun:ddns-porkbun "$LOG_FILE"
    chmod 644 "$LOG_FILE"

    # Configure logrotate
    log_info "Configuring log rotation..."
    cat > "/etc/logrotate.d/$SERVICE_NAME" <<EOF
$LOG_FILE {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 644 ddns-porkbun ddns-porkbun
    postrotate
        systemctl reload-or-restart $SERVICE_NAME.service >/dev/null 2>&1 || true
    endscript
}
EOF

    log_success "Logging system configured"
}

# Function to create systemd service and timer
create_systemd_service() {
    log_info "Creating systemd service and timer..."

    # Create service file
    cat > "/etc/systemd/system/$SERVICE_NAME.service" <<EOF
[Unit]
Description=DDNS Porkbun Update Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/$SERVICE_NAME
User=ddns-porkbun
Group=ddns-porkbun
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE
TimeoutStartSec=300
WorkingDirectory=$INSTALL_DIR
EnvironmentFile=-$ENV_FILE

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$LOG_FILE $CONFIG_DIR

[Install]
WantedBy=multi-user.target
EOF

    # Ask for timer interval
    echo
    log_info "Configuring update schedule..."
    echo "Timer interval examples:"
    echo "  5min     - Every 5 minutes"
    echo "  15min    - Every 15 minutes (recommended)"
    echo "  30min    - Every 30 minutes"
    echo "  1h       - Every hour"
    echo

    read -p "Update interval [15min]: " timer_interval
    timer_interval=${timer_interval:-"15min"}

    # Create timer file
    cat > "/etc/systemd/system/$SERVICE_NAME.timer" <<EOF
[Unit]
Description=Run DDNS Porkbun update every $timer_interval
Requires=$SERVICE_NAME.service

[Timer]
OnBootSec=2min
OnUnitActiveSec=$timer_interval
RandomizedDelaySec=30
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Reload systemd and enable timer
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME.timer"
    systemctl start "$SERVICE_NAME.timer"

    log_success "Service and timer created and enabled"
    log_info "Timer scheduled for: every $timer_interval"
}

# Function to display final configuration
display_config() {
    log_info "Final configuration:"
    echo
    echo "=== Configuration File ($CONFIG_FILE) ==="
    cat "$CONFIG_FILE"
    echo
}

# Function to run initial update
run_initial_update() {
    if ask_yes_no "Do you want to run an initial DDNS update now?"; then
        log_info "Running initial DDNS update..."

        if systemctl start "$SERVICE_NAME.service"; then
            sleep 2
            log_success "Initial update started"
            log_info "Check status with: systemctl status $SERVICE_NAME.service"
        else
            log_error "Initial update failed. Check logs at $LOG_FILE"
        fi
    fi
}

# Function to show final status
show_final_status() {
    echo
    log_success "Installation completed!"
    echo
    log_info "Installation summary:"
    echo "  - Configuration file: $CONFIG_FILE"
    echo "  - Environment file: $ENV_FILE"
    echo "  - Scripts installed at: $INSTALL_DIR"
    echo "  - Log file: $LOG_FILE"
    echo "  - Systemd service: $SERVICE_NAME.service"
    echo "  - Systemd timer: $SERVICE_NAME.timer"
    echo
    log_info "Useful commands:"
    echo "  - Check timer status: systemctl status $SERVICE_NAME.timer"
    echo "  - Check service status: systemctl status $SERVICE_NAME.service"
    echo "  - View logs: tail -f $LOG_FILE"
    echo "  - Run manual update: sudo systemctl start $SERVICE_NAME.service"
    echo "  - Edit configuration: sudo nano $CONFIG_FILE"
    echo "  - View next run time: systemctl list-timers $SERVICE_NAME.timer"
    echo
}

# Main function
main() {
    log_info "Starting DDNS Porkbun installation..."

    # Check if running as root
    check_root

    # Step 1: Check dependencies
    check_dependencies

    # Step 2: Create system user
    create_system_user

    # Step 3: Download scripts
    download_scripts

    # Step 4: Initialize configuration
    init_config

    # Step 5: Configure API keys
    configure_api_keys

    # Step 6: Configure DDNS settings
    configure_ddns

    # Step 7: Configure logging
    configure_logging

    # Step 8: Create systemd service and timer
    create_systemd_service

    # Step 9: Display final configuration
    display_config

    # Step 10: Run initial update
    run_initial_update

    # Show final status
    show_final_status
}

# Run main function
main "$@"
