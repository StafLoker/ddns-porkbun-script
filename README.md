# **DDNS Porkbun Script**

This script allows you to automatically update DNS records for your domain/subdomains on Porkbun using their API. It ensures your records are always in sync with your current public IP.

## **Prerequisites**

1. **Install `jq`:**  
   `jq` is a lightweight and flexible command-line JSON processor, required to parse API responses.

   ```bash
   sudo apt install jq
   ```

2. **Create `keys.env` file:**  
   Store your API keys securely in an environment file. Replace `pk` and `sk` with your actual API and Secret API keys from Porkbun.

   ```bash
   echo 'PORKBUN_API_KEY="pk"' > keys.env
   echo 'PORKBUN_SECRET_API_KEY="sk"' >> keys.env
   ```

   Make sure to secure this file:
   ```bash
   chmod 600 keys.env
   ```

3. **Configure your domain and subdomains:**  
   Update the `data.json` file to include your domain and subdomains. Example format:
   ```json
   {
       "domain": "example.com",
       "subdomains": [
           "sub1",
           "sub2"
       ]
   }
   ```

4. **Make the script executable:**  
   Ensure the script has executable permissions:
   ```bash
   chmod +x ddns-porkbun-script.sh
   ```

---

## **Automating with Cron**

To automate the script, use `cron` to schedule periodic and system startup executions:

1. **Open crontab for editing:**
   ```bash
   crontab -e
   ```

2. **Add the following entries:**  
   - **Run every hour:** Updates DNS records every hour.
   - **Run on system reboot:** Ensures DNS updates upon system startup.

   ```bash
   # Every 1 hour
   0 * * * * /path/to/ddns-porkbun-script.sh

   # At system reboot
   @reboot /path/to/ddns-porkbun-script.sh
   ```

3. **Save and exit the crontab editor.**

---

## **Security Notes**

- **Environment File:** Ensure the `keys.env` file is not accessible to other users on the system. Use `chmod 600` to restrict permissions.
- **Avoid Hardcoding Keys:** Use the `source` command to load environment variables securely.

---

## **Testing**

To test the script manually, run:
```bash
./ddns-porkbun-script.sh
```

Verify that the DNS records on Porkbun are updated to match your current public IP.

---

## **Logging**
Check logs
```bash
journalctl -t ddns-porkbun
```

## **License**

This project is released under the MIT License. See the [LICENSE](LICENSE) file for more details.