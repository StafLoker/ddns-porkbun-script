# **DDNS Porkbun Script**

This script allows you to automatically update DNS records for your domain/subdomains on Porkbun using their API. It ensures your records are always in sync with your current public IP.

---

## **Install & Upgrade**

```bash
bash <(curl -Ls "https://raw.githubusercontent.com/StafLoker/ddns-porkbun-script/main/install.sh")
```

---

## **Install Legacy Version (Not Recommended)**

To install a specific version, use the following command. For example, to install version `v1.0.1`:

```bash
VERSION=v1.0.1 && bash <(curl -Ls "https://raw.githubusercontent.com/StafLoker/ddns-porkbun-script/main/install.sh") $VERSION
```

---

## **Manual Install**

### **Prerequisites**

1. **Download the Project:**  
   Clone or download the project from the GitHub repository (replace `${VERSION}` with the version of the latest release):

   ```bash
   sudo mkdir -p /opt/ddns-porkbun-script
   cd /opt/ddns-porkbun-script
   sudo wget https://github.com/StafLoker/ddns-porkbun-script/archive/refs/tags/${VERSION}.tar.gz
   sudo tar -xzvf ${VERSION}.tar.gz
   sudo rm ${VERSION}.tar.gz
   ```

   This will download the latest version of the script and extract it into the `/opt/ddns-porkbun-script` directory.

2. **Install `jq`:**  
   `jq` is a lightweight and flexible command-line JSON processor, required to parse API responses.

   ```bash
   sudo apt install jq
   ```

3. **Create `keys.env` file:**  
   Store your API keys securely in an environment file. Replace `pk` and `sk` with your actual API and Secret API keys from Porkbun.

   ```bash
   echo 'PORKBUN_API_KEY="pk"' > keys.env
   echo 'PORKBUN_SECRET_API_KEY="sk"' >> keys.env
   ```

   Make sure to secure this file:
   ```bash
   chmod 600 keys.env
   ```

4. **Configure your domain and subdomains:**  
   Create the `data.json` file to include your domain and subdomains. Example format:
   ```json
   {
       "domain": "example.com",
       "concurrency": true,
       "ipv4": true,
       "subdomains_type_a": [
           "sub1",
           "sub2"
       ],
       "ipv6": false,
       "subdomains_type_aaaa": [
           "sub3",
           "sub4"
       ]
   }
   ```

5. **Make the script executable:**  
   Ensure the script has executable permissions:
   ```bash
   chmod +x ddns-porkbun-script.sh
   ```

---

### **Create System User**

For security reasons, it is recommended to run the script as a dedicated system user. Follow these steps to create the user:

1. **Create the user:**  
   Replace `/opt/ddns-porkbun-script` with your installation directory.

   ```bash
   sudo useradd -r -d /opt/ddns-porkbun-script -c "User for the DDNS Porkbun script" ddns-system
   ```

2. **Set ownership of the installation directory:**  
   Ensure the user `ddns-system` owns the installation directory.

   ```bash
   sudo chown -R ddns-system:ddns-system /opt/ddns-porkbun-script
   ```

---

### **Choose Between Cron and Systemd**

You can automate the script using either `cron` or `systemd`. Below are instructions for both methods.

#### **Option 1: Automating with Cron**

1. **Open crontab for editing:**
   ```bash
   crontab -e
   ```

2. **Add the following entries:**  
   - **Run every hour:** Updates DNS records every hour.
   - **Run on system reboot:** Ensures DNS updates upon system startup.

   ```bash
   # Every 1 hour
   0 * * * * /opt/ddns-porkbun-script/ddns-porkbun-script.sh

   # At system reboot
   @reboot /opt/ddns-porkbun-script/ddns-porkbun-script.sh
   ```

3. **Save and exit the crontab editor.**

4. **Updating `ddns-porkbun-script.sh` for Cron Compatibility**  
   Ensure the script uses absolute paths for `keys.env` and `data.json`:

   ```bash
   # Load keys
   source /opt/ddns-porkbun-script/keys.env

   # Load JSON
   DATA_FILE="/opt/ddns-porkbun-script/data.json"
   ```

5. **Verify the Cron job:**  
   Execute the script manually to confirm it works without errors:
   ```bash
   /opt/ddns-porkbun-script/ddns-porkbun-script.sh
   ```

---

#### **Option 2: Automating with Systemd**

1. **Create the systemd service file:**  
   Replace `/opt/ddns-porkbun-script` with your installation directory.

   ```bash
   sudo bash -c "cat > /etc/systemd/system/ddns-porkbun.service <<EOF
   [Unit]
   Description=DDNS Porkbun Update Service
   After=network.target

   [Service]
   User=ddns-system
   ExecStart=/opt/ddns-porkbun-script/ddns-porkbun-script.sh

   [Install]
   WantedBy=multi-user.target
   EOF"
   ```

2. **Create the systemd timer file:**  
   Replace `1h` with your desired execution interval (e.g., `15min`, `1h`).

   ```bash
   sudo bash -c "cat > /etc/systemd/system/ddns-porkbun.timer <<EOF
   [Unit]
   Description=Run DDNS Porkbun script every 1h

   [Timer]
   OnBootSec=5min
   OnUnitActiveSec=1h
   Unit=ddns-porkbun.service

   [Install]
   WantedBy=timers.target
   EOF"
   ```

3. **Reload systemd and enable the timer:**
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now ddns-porkbun.timer
   ```

4. **Verify the timer is active:**
   ```bash
   systemctl list-timers --all
   ```

---

## **Security Notes**

- **Environment File:** Ensure the `keys.env` file is not accessible to other users on the system. Use `chmod 600` to restrict permissions.
- **Avoid Hardcoding Keys:** Use the `source` command to load environment variables securely.

---

## **Testing**

To test the script manually, run:
```bash
/opt/ddns-porkbun-script/ddns-porkbun-script.sh
```

Verify that the DNS records on Porkbun are updated to match your current public IP.

---

## **Logging**

Check logs using `journalctl`:
```bash
journalctl -t ddns-porkbun | tail
```

---

## **License**

This project is released under the MIT License. See the [LICENSE](LICENSE) file for more details.