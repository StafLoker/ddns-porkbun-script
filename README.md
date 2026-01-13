<div align="center">
   <h1><b>DDNS Porkbun Script</b></h1>
   <p><i>~ Still online ~</i></p>
   <p align="center">
       · <a href="https://github.com/StafLoker/ddns-porkbun-script/releases">Releases</a> ·
   </p>
</div>

<div align="center">
   <a href="https://github.com/StafLoker/ddns-porkbun-script/releases"><img src="https://img.shields.io/github/release-pre/StafLoker/ddns-porkbun-script.svg?style=flat" alt="latest version"/></a>
   <a href="https://github.com/StafLoker/ddns-porkbun-script/blob/main/LICENSE"><img src="https://img.shields.io/github/license/StafLoker/ddns-porkbun-script.svg?style=flat" alt="license"/></a>

   <p>This script automatically updates DNS records for your domain/subdomains on Porkbun using their API. It ensures your records are always in sync with your current public IP addresses (both IPv4 and IPv6).</p>
</div>

## Alerts

> [!IMPORTANT]
> Impossible migrate from `1.x.x` to `2.x.x`.
> Please remove completely version `1.x.x` and install `2.x.x`.

---

## **Quick Install & Upgrade**

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/StafLoker/ddns-porkbun-script/main/install.sh)"
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

| File/Directory  | Location                                   | Purpose                       |
| --------------- | ------------------------------------------ | ----------------------------- |
| Configuration   | `/etc/ddns-porkbun/config.yaml`            | DDNS settings                 |
| API Keys        | `/etc/ddns-porkbun/.env`                   | Porkbun API credentials       |
| Scripts         | `/opt/ddns-porkbun/`                       | Main script and documentation |
| Logs            | `/var/log/ddns-porkbun.log`                | Service logs with rotation    |
| Systemd Service | `/etc/systemd/system/ddns-porkbun.service` | Service definition            |
| Systemd Timer   | `/etc/systemd/system/ddns-porkbun.timer`   | Scheduling                    |
| Executable      | `/usr/local/bin/ddns-porkbun`              | Symlink to main script        |

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
sudo vim /etc/ddns-porkbun/config.yaml

# Edit API keys
sudo vim /etc/ddns-porkbun/.env

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
- **Automatic dependency installation**: The installer automatically detects and installs missing dependencies:
  - `curl`, `wget`, `jq`, `sed`, `tar`
  - **`yq` (mikefarah/yq)**: Automatically downloaded and installed with architecture detection
    - Supports: x86_64, aarch64/arm64, armv7l/armv6l, i386/i686

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

4. **yq version conflicts:**
   - The installer automatically handles yq installation
   - If you have issues, remove existing yq: `sudo apt remove yq && sudo pip3 uninstall yq`
   - Then reinstall using the manual yq installation steps above

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

# Optionally remove yq if not needed elsewhere
sudo rm -f /usr/local/bin/yq
```

---

## **License**

This project is released under the MIT License. See the [LICENSE](LICENSE) file for more details.
