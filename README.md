# **DDNS Porkbun Script**

This script automatically updates DNS records for your domain/subdomains on Porkbun using their API. It ensures your records are always in sync with your current public IP addresses (both IPv4 and IPv6).

---

## **Quick Install & Upgrade**

```bash
sudo bash <(curl -Ls "https://raw.githubusercontent.com/StafLoker/ddns-porkbun-script/main/install.sh")
```

---

## **Configuration**

The script uses YAML configuration with the following structure:

```yaml
domain: example.com
concurrency: true
ipv4:
  enable: true
  subdomains:
    - sub1
    - sub2
    - www
ipv6:
  enable: false
  subdomains:
    - sub3
    - sub4
```

### **Configuration Options:**

- **`domain`**: Your main domain (e.g., `example.com`)
- **`concurrency`**: Enable parallel processing of subdomains (`true`/`false`)
- **`ipv4.enable`**: Enable IPv4 record updates (`true`/`false`)
- **`ipv4.subdomains`**: List of subdomains for A records
- **`ipv6.enable`**: Enable IPv6 record updates (`true`/`false`)
- **`ipv6.subdomains`**: List of subdomains for AAAA records

---

## **File Locations**

After installation, files are organized in standard Linux locations:

| File/Directory | Location | Purpose |
|---|---|---|
| Configuration | `/etc/ddns-porkbun/config.yaml` | DDNS settings |
| API Keys | `/etc/ddns-porkbun/.env` | Porkbun API credentials |
| Scripts | `/opt/ddns-porkbun/` | Main script and documentation |
| Logs | `/var/log/ddns-porkbun.log` | Service logs with rotation |
| Systemd Service | `/etc/systemd/system/ddns-porkbun.service` | Service definition |
| Systemd Timer | `/etc/systemd/system/ddns-porkbun.timer` | Scheduling |
| Executable | `/usr/local/bin/ddns-porkbun` | Symlink to main script |

---

## **Management Commands**

### **Service Management:**
```bash
# Check service status
sudo systemctl status ddns-porkbun.service

# Check timer status
sudo systemctl status ddns-porkbun.timer

# View next scheduled runs
systemctl list-timers ddns-porkbun.timer

# Run manual update
sudo systemctl start ddns-porkbun.service
```

### **Logs:**
```bash
# View recent logs
sudo tail -f /var/log/ddns-porkbun.log

# View systemd logs
sudo journalctl -u ddns-porkbun.service -f

# View all ddns-porkbun logs
sudo journalctl -t ddns-porkbun
```

### **Configuration:**
```bash
# Edit main configuration
sudo nano /etc/ddns-porkbun/config.yaml

# Edit API keys
sudo nano /etc/ddns-porkbun/.env

# Restart after config changes
sudo systemctl restart ddns-porkbun.timer
```

---

## **Security Features**

- **Dedicated system user**: Runs as `ddns-porkbun` user with minimal privileges
- **Secure file permissions**: 
  - API keys file (`.env`): `600` (owner read-only)
  - Configuration file: `640` (owner read/write, group read)
- **Systemd hardening**: 
  - `NoNewPrivileges=true`
  - `PrivateTmp=true`
  - `ProtectSystem=strict`
  - `ProtectHome=true`
- **Log rotation**: Automatic cleanup with 14-day retention

---

## **Prerequisites**

### **Porkbun API Setup:**
1. Go to [Porkbun API Settings](https://porkbun.com/account/api)
2. Enable API access for your domain
3. Generate API Key and Secret API Key
4. Note down both keys for the installation process

### **System Requirements:**
- Linux system with systemd
- Root/sudo access for installation
- Internet connectivity for API calls
- The following packages (auto-installed if missing):
  - `curl`, `wget`, `jq`, `yq`, `sed`, `tar`

---

## **Manual Installation**

If you prefer manual installation or need to customize the setup:

### **1. Download and Extract:**
```bash
# Create installation directory
sudo mkdir -p /opt/ddns-porkbun

# Download latest release
VERSION=$(curl -s https://api.github.com/repos/StafLoker/ddns-porkbun-script/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
sudo wget -P /opt/ddns-porkbun "https://github.com/StafLoker/ddns-porkbun-script/archive/refs/tags/${VERSION}.tar.gz"
sudo tar -xzf "/opt/ddns-porkbun/${VERSION}.tar.gz" -C /opt/ddns-porkbun
sudo mv /opt/ddns-porkbun/ddns-porkbun-script-${VERSION#v}/* /opt/ddns-porkbun/
sudo rm -rf "/opt/ddns-porkbun/ddns-porkbun-script-${VERSION#v}" "/opt/ddns-porkbun/${VERSION}.tar.gz"
```

### **2. Install Dependencies:**
```bash
# Install required packages
sudo apt update
sudo apt install -y curl wget jq sed tar

# Install yq
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
```

### **3. Create System User:**
```bash
sudo useradd -r -s /bin/false -d /nonexistent -c "DDNS Porkbun service user" ddns-porkbun
```

### **4. Set Up Configuration:**
```bash
# Create configuration directory
sudo mkdir -p /etc/ddns-porkbun
sudo chown ddns-porkbun:ddns-porkbun /etc/ddns-porkbun
sudo chmod 750 /etc/ddns-porkbun

# Create API keys file
sudo tee /etc/ddns-porkbun/.env > /dev/null <<EOF
PORKBUN_API_KEY="your_api_key_here"
PORKBUN_SECRET_API_KEY="your_secret_key_here"
EOF

sudo chown ddns-porkbun:ddns-porkbun /etc/ddns-porkbun/.env
sudo chmod 600 /etc/ddns-porkbun/.env

# Create configuration file
sudo tee /etc/ddns-porkbun/config.yaml > /dev/null <<EOF
domain: example.com
concurrency: true
ipv4:
  enable: true
  subdomains:
    - www
    - mail
ipv6:
  enable: false
  subdomains: []
EOF

sudo chown ddns-porkbun:ddns-porkbun /etc/ddns-porkbun/config.yaml
sudo chmod 640 /etc/ddns-porkbun/config.yaml
```

### **5. Update Script Paths:**
```bash
sudo chmod +x /opt/ddns-porkbun/ddns-porkbun-script.sh
sudo ln -sf /opt/ddns-porkbun/ddns-porkbun-script.sh /usr/local/bin/ddns-porkbun
```

### **6. Create Systemd Service:**
```bash
# Create service file
sudo tee /etc/systemd/system/ddns-porkbun.service > /dev/null <<EOF
[Unit]
Description=DDNS Porkbun Update Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/ddns-porkbun
User=ddns-porkbun
Group=ddns-porkbun
StandardOutput=append:/var/log/ddns-porkbun.log
StandardError=append:/var/log/ddns-porkbun.log
TimeoutStartSec=300
WorkingDirectory=/opt/ddns-porkbun
EnvironmentFile=-/etc/ddns-porkbun/.env

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log/ddns-porkbun.log /etc/ddns-porkbun

[Install]
WantedBy=multi-user.target
EOF

# Create timer file
sudo tee /etc/systemd/system/ddns-porkbun.timer > /dev/null <<EOF
[Unit]
Description=Run DDNS Porkbun update every 15min
Requires=ddns-porkbun.service

[Timer]
OnBootSec=2min
OnUnitActiveSec=15min
RandomizedDelaySec=30
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable --now ddns-porkbun.timer
```

### **7. Set Up Logging:**
```bash
# Create log file
sudo touch /var/log/ddns-porkbun.log
sudo chown ddns-porkbun:ddns-porkbun /var/log/ddns-porkbun.log
sudo chmod 644 /var/log/ddns-porkbun.log

# Configure log rotation
sudo tee /etc/logrotate.d/ddns-porkbun > /dev/null <<EOF
/var/log/ddns-porkbun.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 644 ddns-porkbun ddns-porkbun
    postrotate
        systemctl reload-or-restart ddns-porkbun.service >/dev/null 2>&1 || true
    endscript
}
EOF
```

---

## **Troubleshooting**

### **Common Issues:**

1. **Permission denied errors:**
   ```bash
   # Fix file permissions
   sudo chown -R ddns-porkbun:ddns-porkbun /etc/ddns-porkbun
   sudo chmod 600 /etc/ddns-porkbun/.env
   sudo chmod 640 /etc/ddns-porkbun/config.yaml
   ```

2. **API authentication failures:**
   - Verify API keys in `/etc/ddns-porkbun/.env`
   - Ensure API access is enabled for your domain in Porkbun
   - Check that domain is correctly spelled in config

3. **Service not starting:**
   ```bash
   # Check service status
   sudo systemctl status ddns-porkbun.service
   
   # View detailed logs
   sudo journalctl -u ddns-porkbun.service -n 50
   ```

4. **Missing dependencies:**
   ```bash
   # Install missing tools
   sudo apt install -y curl wget jq sed tar
   
   # Install yq manually
   sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
   sudo chmod +x /usr/local/bin/yq
   ```

### **Debug Mode:**
Run the script manually to see detailed output:
```bash
sudo -u ddns-porkbun /usr/local/bin/ddns-porkbun
```

---

## **Uninstall**

To completely remove the DDNS service:

```bash
# Stop and disable services
sudo systemctl stop ddns-porkbun.timer ddns-porkbun.service
sudo systemctl disable ddns-porkbun.timer ddns-porkbun.service

# Remove systemd files
sudo rm -f /etc/systemd/system/ddns-porkbun.{service,timer}
sudo systemctl daemon-reload

# Remove user and files
sudo userdel ddns-porkbun
sudo rm -rf /etc/ddns-porkbun /opt/ddns-porkbun /var/log/ddns-porkbun.log
sudo rm -f /usr/local/bin/ddns-porkbun /etc/logrotate.d/ddns-porkbun
```

---

## **License**

This project is released under the MIT License. See the [LICENSE](LICENSE) file for more details.