#!/bin/bash

# Color Definitions
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[32m'
RESET='\033[0m'

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

# Check if a version is provided, if not set a default version (latest)
if [ -z "$1" ]; then
    log_info "No version provided. Installing the latest release."
    VERSION=$(curl -Ls "https://api.github.com/repos/StafLoker/ddns-porkbun-script/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
else
    VERSION=$1
fi

if [ -z "$VERSION" ]; then
    log_error "Failed to determine the version. Exiting."
    exit 1
fi

log_success "Installing ddns-porkbun-script version $VERSION..."

# Define the installation directory as the 'ddns-porkbun-script' folder in the user's home directory
install_dir="$HOME/ddns-porkbun-script"

# Create the directory if it doesn't exist
if [ ! -d "$install_dir" ]; then
    log_info "Creating directory: $install_dir"
    mkdir -p "$install_dir"
else
    log_success "Directory $install_dir already exists."
fi

# Download the specific version's tar.gz file
url="https://github.com/StafLoker/ddns-porkbun-script/archive/refs/tags/${VERSION}.tar.gz"
log_info "Downloading version ${VERSION} from $url"
wget -N --no-check-certificate -O "${install_dir}/ddns-porkbun-script-${VERSION}.tar.gz" ${url}

# Check if the download was successful
if [[ $? -ne 0 ]]; then
    log_error "Failed to download ddns-porkbun-script version $VERSION. Please check if the version exists."
    exit 1
fi

log_info "Extracting the downloaded tar.gz file..."
# Extract the downloaded tar.gz file into the installation directory
tar -xzvf "${install_dir}/ddns-porkbun-script-${VERSION}.tar.gz" -C "$install_dir"
rm -f "${install_dir}/ddns-porkbun-script-${VERSION}.tar.gz"

# Move the extracted files to the correct location
mv "${install_dir}/ddns-porkbun-script-${VERSION}"/* "$install_dir/"
rmdir "${install_dir}/ddns-porkbun-script-${VERSION}"

log_info "Removing unwanted files (.git, .gitignore)..."
# Remove .git and .gitignore if they exist in the install directory
rm -rf "${install_dir}/.git" "${install_dir}/.gitignore"

log_info "Checking for keys.env file..."
# Create the keys.env file if it doesn't exist in the install directory
if [ ! -f "${install_dir}/keys.env" ]; then
    log_info "Creating keys.env file..."
    echo 'PORKBUN_API_KEY="pk"' > "${install_dir}/keys.env"
    echo 'PORKBUN_SECRET_API_KEY="sk"' >> "${install_dir}/keys.env"
    chmod 600 "${install_dir}/keys.env"
else
    log_success "keys.env file already exists."
fi

log_info "Checking for data.json file..."
# Create the data.json file if it doesn't exist in the install directory
if [ ! -f "${install_dir}/data.json" ]; then
    log_info "Creating data.json file..."
    cat <<EOF > "${install_dir}/data.json"
{
    "domain": "example.com",
    "concurrency": true,
    "subdomains": [
        "sub1",
        "sub2"
    ]
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