# Complete Bare-Metal Monitoring Stack Installation Guide
## Ubuntu 25.04 - Prometheus + Grafana + Node Exporter + Gitea Monitoring

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [System Preparation](#system-preparation)
3. [Prometheus Installation](#prometheus-installation)
4. [Node Exporter Installation](#node-exporter-installation)
5. [Grafana Installation](#grafana-installation)
6. [Gitea Installation & Metrics](#gitea-installation--metrics)
7. [Gitea Runner Setup (Optional)](#gitea-runner-setup-optional)
8. [cAdvisor Installation (Optional)](#cadvisor-installation-optional)
9. [Verification & Testing](#verification--testing)
10. [Access & Configuration](#access--configuration)
11. [Firewall Setup](#firewall-setup)
12. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### System Requirements
- Ubuntu 25.04 (Plucky Puffin) server
- At least 2GB RAM (4GB recommended)
- At least 10GB free disk space
- sudo access
- Internet connectivity
- Ports available: 9090, 3000, 9100, 8091

### Before You Start
```bash
# Run this to verify your system
cat /etc/os-release
uname -m
free -h
df -h
```

Should show:
- OS: Ubuntu 25.04
- Architecture: x86_64
- RAM: 2GB+
- Disk: 10GB+ free

---

## System Preparation

### Step 1: Update System Packages

```bash
# Update package lists
sudo apt update

# Upgrade all packages
sudo apt upgrade -y

# Install common dependencies
sudo apt install -y \
    wget \
    curl \
    tar \
    gzip \
    vim \
    net-tools \
    software-properties-common \
    build-essential
```

**Expected output:** Packages successfully installed

---

### Step 2: Check Network Connectivity

```bash
# Test internet connection
curl -I https://github.com

# Check DNS resolution
nslookup github.com

# Verify you can reach package servers
ping -c 1 archive.ubuntu.com
```

**Expected output:** All commands return successfully without errors

---

## Prometheus Installation

### Step 3: Create Prometheus User and Directories

```bash
# Create system user for Prometheus (without home directory or shell)
sudo useradd --no-create-home --shell /bin/false prometheus
```

Verify:
```bash
id prometheus
# Output: uid=XXX gid=XXX groups=XXX
```

### Step 4: Create Prometheus Directories

```bash
# Create configuration directory
sudo mkdir -p /etc/prometheus

# Create data directory
sudo mkdir -p /var/lib/prometheus

# Verify directories exist
ls -la /etc/prometheus
ls -la /var/lib/prometheus
```

**Expected output:** Empty directories created

---

### Step 5: Download and Install Prometheus Binary

```bash
# Change to temporary directory
cd /tmp

# Download Prometheus (check latest version at https://prometheus.io/download/)
wget https://github.com/prometheus/prometheus/releases/download/v2.48.0/prometheus-2.48.0.linux-amd64.tar.gz

# Verify download
ls -lh prometheus-2.48.0.linux-amd64.tar.gz
```

**Expected output:** File size should be ~120MB

### Step 6: Extract Prometheus Archive

```bash
# Extract the archive
tar xvfz prometheus-2.48.0.linux-amd64.tar.gz

# List extracted contents
ls -la prometheus-2.48.0.linux-amd64/

# Should show: prometheus, promtool, consoles, console_libraries
```

---

### Step 7: Copy Prometheus Binaries to System Path

```bash
# Copy main binary
sudo cp prometheus-2.48.0.linux-amd64/prometheus /usr/local/bin/

# Copy tool binary
sudo cp prometheus-2.48.0.linux-amd64/promtool /usr/local/bin/

# Verify installation
prometheus --version
promtool --version
```

**Expected output:**
```
prometheus, version 2.48.0, build ...
promtool, version 2.48.0, build ...
```

---

### Step 8: Copy Console Templates

```bash
# Copy consoles
sudo cp -r prometheus-2.48.0.linux-amd64/consoles /etc/prometheus/

# Copy console libraries
sudo cp -r prometheus-2.48.0.linux-amd64/console_libraries /etc/prometheus/

# Verify
ls -la /etc/prometheus/
```

**Expected output:** consoles and console_libraries directories visible

---

### Step 9: Set Permissions

```bash
# Set ownership of all Prometheus directories
sudo chown -R prometheus:prometheus /etc/prometheus
sudo chown -R prometheus:prometheus /var/lib/prometheus

# Verify permissions
ls -la /etc/prometheus
ls -la /var/lib/prometheus
```

**Expected output:** All files owned by prometheus:prometheus

---

### Step 10: Create Prometheus Configuration File

```bash
# Create and open configuration file
sudo nano /etc/prometheus/prometheus.yml
```

**Copy and paste the entire content below** (this is critical for proper indentation):

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: 'monitoring-stack'

alerting:
  alertmanagers:
    - static_configs:
        - targets: []

rule_files: []

scrape_configs:
  # Prometheus monitoring itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Node Exporter - Server metrics
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']

  # Gitea metrics
  - job_name: 'gitea'
    static_configs:
      - targets: ['localhost:3000']
    metrics_path: '/metrics'
    scrape_interval: 30s
    scrape_timeout: 10s

  # Grafana metrics
  - job_name: 'grafana'
    static_configs:
      - targets: ['localhost:3000']
    metrics_path: '/metrics'
    scrape_interval: 30s
```

**To save:**
- Press: `Ctrl + X`
- Press: `Y` (yes)
- Press: `Enter` (confirm filename)

### Step 11: Verify Prometheus Configuration

```bash
# Validate configuration syntax
sudo -u prometheus /usr/local/bin/promtool check config /etc/prometheus/prometheus.yml
```

**Expected output:**
```
Checking /etc/prometheus/prometheus.yml
 SUCCESS: 0 error(s)
```

### Step 12: Set Configuration File Permissions

```bash
# Set ownership
sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml

# Set read permissions
sudo chmod 644 /etc/prometheus/prometheus.yml

# Verify
ls -la /etc/prometheus/prometheus.yml
```

**Expected output:** -rw-r--r-- 1 prometheus prometheus

---

### Step 13: Create Prometheus Systemd Service File

```bash
# Open systemd service file editor
sudo nano /etc/systemd/system/prometheus.service
```

**Copy and paste the entire content below:**

```ini
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/prometheus \
  --config.file /etc/prometheus/prometheus.yml \
  --storage.tsdb.path /var/lib/prometheus/ \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --storage.tsdb.retention.time=30d

Restart=on-failure
RestartSec=5s

StandardOutput=journal
StandardError=journal
SyslogIdentifier=prometheus

[Install]
WantedBy=multi-user.target
```

**To save:**
- Press: `Ctrl + X`
- Press: `Y` (yes)
- Press: `Enter` (confirm filename)

### Step 14: Reload Systemd and Enable Prometheus

```bash
# Reload systemd daemon (required after creating new service files)
sudo systemctl daemon-reload

# Enable Prometheus to start on boot
sudo systemctl enable prometheus

# Verify it was enabled
sudo systemctl is-enabled prometheus
```

**Expected output:** enabled

---

### Step 15: Start Prometheus Service

```bash
# Start Prometheus
sudo systemctl start prometheus

# Check status
sudo systemctl status prometheus
```

**Expected output:**
```
● prometheus.service - Prometheus
     Loaded: loaded (/etc/systemd/system/prometheus.service; enabled; ...)
     Active: active (running) since ...
```

### Step 16: Verify Prometheus is Running

```bash
# Check if port 9090 is listening
sudo ss -tlnp | grep 9090

# Test connectivity
curl http://localhost:9090/-/healthy

# Check service logs
sudo journalctl -u prometheus -n 20
```

**Expected output:**
- Port 9090 should be LISTEN
- curl should return healthy response
- No errors in logs

---

## Node Exporter Installation

### Step 17: Create Node Exporter User

```bash
# Create system user
sudo useradd --no-create-home --shell /bin/false node_exporter

# Verify
id node_exporter
```

### Step 18: Download and Install Node Exporter

```bash
# Change to temp directory
cd /tmp

# Download Node Exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz

# Verify download
ls -lh node_exporter-1.7.0.linux-amd64.tar.gz
```

**Expected output:** File size ~12MB

### Step 19: Extract and Install Node Exporter Binary

```bash
# Extract
tar xvfz node_exporter-1.7.0.linux-amd64.tar.gz

# Copy binary to system path
sudo cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/

# Set permissions
sudo chmod +x /usr/local/bin/node_exporter

# Set ownership
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Verify installation
node_exporter --version
```

**Expected output:**
```
node_exporter, version 1.7.0, build ...
```

---

### Step 20: Create Node Exporter Systemd Service

```bash
# Open service file
sudo nano /etc/systemd/system/node_exporter.service
```

**Copy and paste the entire content below:**

```ini
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter

Restart=on-failure
RestartSec=5s

StandardOutput=journal
StandardError=journal
SyslogIdentifier=node_exporter

[Install]
WantedBy=multi-user.target
```

**To save:** Ctrl+X, Y, Enter

### Step 21: Enable and Start Node Exporter

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable on boot
sudo systemctl enable node_exporter

# Start service
sudo systemctl start node_exporter

# Check status
sudo systemctl status node_exporter
```

**Expected output:** active (running)

### Step 22: Verify Node Exporter

```bash
# Check if port 9100 is listening
sudo ss -tlnp | grep 9100

# Test metrics endpoint
curl http://localhost:9100/metrics | head -20

# Should see many metrics starting with: # HELP node_
```

---

## Grafana Installation

### Step 23: Add Grafana Repository

```bash
# Add Grafana GPG key
sudo apt install -y software-properties-common

# Add repository
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"

# Import GPG key
wget -q -O /usr/share/keyrings/grafana.key https://packages.grafana.com/gpg.key

# Update package list
sudo apt update
```

**Expected output:** Repository added and keys installed

### Step 24: Install Grafana Server

```bash
# Install Grafana
sudo apt install -y grafana-server

# Verify installation
grafana-server --version
```

**Expected output:** Version number displayed

### Step 25: Enable and Start Grafana

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable on boot
sudo systemctl enable grafana-server

# Start Grafana
sudo systemctl start grafana-server

# Check status
sudo systemctl status grafana-server
```

**Expected output:** active (running)

### Step 26: Verify Grafana is Running

```bash
# Check port 3000
sudo ss -tlnp | grep 3000

# Test connectivity
curl http://localhost:3000/api/health

# Check logs
sudo journalctl -u grafana-server -n 20
```

**Expected output:**
- Port 3000 listening
- curl returns health status
- No errors in logs

---

## Gitea Installation & Metrics

### Step 27: Create Gitea User

```bash
# Create git user
sudo useradd -m -s /bin/bash git

# Verify
id git
```

### Step 28: Create Gitea Directories

```bash
# Create application directory
sudo mkdir -p /var/lib/gitea

# Create configuration directory
sudo mkdir -p /etc/gitea

# Set ownership
sudo chown -R git:git /var/lib/gitea
sudo chown -R git:git /etc/gitea

# Verify
ls -la /var/lib/gitea
ls -la /etc/gitea
```

### Step 29: Download Gitea Binary

```bash
# Change to temp directory
cd /tmp

# Download Gitea (check latest version at https://github.com/go-gitea/gitea/releases)
wget https://github.com/go-gitea/gitea/releases/download/v1.21.5/gitea-1.21.5-linux-amd64

# Verify download
ls -lh gitea-1.21.5-linux-amd64
```

**Expected output:** File size ~100MB

### Step 30: Install Gitea Binary

```bash
# Copy to system path
sudo mv /tmp/gitea-1.21.5-linux-amd64 /usr/local/bin/gitea

# Make executable
sudo chmod +x /usr/local/bin/gitea

# Verify
gitea --version
```

**Expected output:**
```
Gitea version X.X.X
```

---

### Step 31: Create Gitea Systemd Service

```bash
# Open service file
sudo nano /etc/systemd/system/gitea.service
```

**Copy and paste the entire content below:**

```ini
[Unit]
Description=Gitea
After=syslog.target network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=simple
User=git
Group=git
WorkingDirectory=/var/lib/gitea
ExecStart=/usr/local/bin/gitea web -c /etc/gitea/app.ini
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal
SyslogIdentifier=gitea
Environment="USER=git" "HOME=/home/git"

[Install]
WantedBy=multi-user.target
```

**To save:** Ctrl+X, Y, Enter

### Step 32: Enable and Start Gitea

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable on boot
sudo systemctl enable gitea

# Start Gitea
sudo systemctl start gitea

# Check status
sudo systemctl status gitea
```

**Expected output:** active (running)

### Step 33: Access Gitea Web Setup

```bash
# Check if Gitea is responding
curl http://localhost:3000/

# Check status
sudo systemctl status gitea

# View logs
sudo journalctl -u gitea -n 30
```

**Expected output:** Gitea web interface responds, no errors in logs

### Step 34: Complete Gitea Web Setup

1. Open browser: `http://localhost:3000/`
2. Complete installation wizard:
   - Database: SQLite3 (default)
   - Application URL: `http://localhost:3000/`
   - Admin account: Create username/password
   - Click: **Install Gitea**

3. After installation, verify:
   ```bash
   curl http://localhost:3000/
   ```

### Step 35: Enable Gitea Metrics

```bash
# Open Gitea configuration
sudo nano /etc/gitea/app.ini
```

Find or add the `[metrics]` section and add these lines:

```ini
[metrics]
ENABLED = true
ENABLE_USER_AGENT = true
ENABLE_API = true
```

**To save:** Ctrl+X, Y, Enter

### Step 36: Restart Gitea with Metrics Enabled

```bash
# Restart Gitea
sudo systemctl restart gitea

# Wait for it to start
sleep 3

# Verify metrics endpoint
curl http://localhost:3000/metrics | head -20

# Should see metrics like: gitea_*
```

**Expected output:** Metrics data displayed

---

## Gitea Runner Setup (Optional)

> This is optional. Only proceed if you want CI/CD functionality.

### Step 37: Create Act Runner User

```bash
# Create user
sudo useradd -m -s /bin/bash act_runner

# Verify
id act_runner
```

### Step 38: Download Act Runner

```bash
# Change to temp directory
cd /tmp

# Download (get latest from https://github.com/nektos/act/releases)
wget https://github.com/nektos/act/releases/download/v0.2.47/act_0.2.47_linux_x86_64.tar.gz

# Extract
tar xvfz act_0.2.47_linux_x86_64.tar.gz

# Copy binary
sudo cp act /usr/local/bin/act_runner

# Make executable
sudo chmod +x /usr/local/bin/act_runner

# Verify
act_runner --version
```

### Step 39: Create Act Runner Directories

```bash
# Create runner directory
sudo mkdir -p /var/lib/act_runner

# Set ownership
sudo chown -R act_runner:act_runner /var/lib/act_runner

# Verify
ls -la /var/lib/act_runner
```

### Step 40: Create Act Runner Systemd Service

```bash
# Open service file
sudo nano /etc/systemd/system/act_runner.service
```

**Copy and paste:**

```ini
[Unit]
Description=Gitea Act Runner
After=network.target gitea.service

[Service]
Type=simple
User=act_runner
Group=act_runner
WorkingDirectory=/var/lib/act_runner
ExecStart=/usr/local/bin/act_runner daemon

Restart=on-failure
RestartSec=5s

StandardOutput=journal
StandardError=journal
SyslogIdentifier=act_runner

[Install]
WantedBy=multi-user.target
```

**To save:** Ctrl+X, Y, Enter

### Step 41: Enable and Start Act Runner

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable
sudo systemctl enable act_runner

# Start
sudo systemctl start act_runner

# Check status
sudo systemctl status act_runner

# View logs
sudo journalctl -u act_runner -n 20
```

---

## cAdvisor Installation (Optional)

> This is optional. Only proceed if you want Docker container monitoring.

### Step 42: Download cAdvisor

```bash
# Change to temp directory
cd /tmp

# Download cAdvisor (get latest from https://github.com/google/cadvisor/releases)
wget https://github.com/google/cadvisor/releases/download/v0.48.0/cadvisor

# Make executable
chmod +x cadvisor

# Copy to system path
sudo cp cadvisor /usr/local/bin/

# Verify
cadvisor --version
```

### Step 43: Create cAdvisor Systemd Service

```bash
# Open service file
sudo nano /etc/systemd/system/cadvisor.service
```

**Copy and paste:**

```ini
[Unit]
Description=cAdvisor
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/cadvisor \
  --port=8080 \
  --housekeeping_interval=10s \
  --stats_housekeeping_interval=10s
Restart=on-failure
RestartSec=5s

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

**To save:** Ctrl+X, Y, Enter

### Step 44: Enable and Start cAdvisor

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable
sudo systemctl enable cadvisor

# Start
sudo systemctl start cadvisor

# Check status
sudo systemctl status cadvisor

# Test
curl http://localhost:8080/containers/
```

### Step 45: Add cAdvisor to Prometheus (Optional)

```bash
# Edit Prometheus config
sudo nano /etc/prometheus/prometheus.yml
```

Add this section at the end of `scrape_configs`:

```yaml
  # cAdvisor - Docker container metrics
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['localhost:8080']
    metrics_path: '/metrics'
    scrape_interval: 30s
```

```bash
# Reload Prometheus
sudo systemctl restart prometheus

# Verify
sleep 2
curl http://localhost:9090/-/healthy
```

---

## Verification & Testing

### Step 46: Check All Services Status

```bash
# Check all services at once
echo "=== Prometheus ===" && sudo systemctl status prometheus --no-pager | head -5
echo ""
echo "=== Node Exporter ===" && sudo systemctl status node_exporter --no-pager | head -5
echo ""
echo "=== Grafana ===" && sudo systemctl status grafana-server --no-pager | head -5
echo ""
echo "=== Gitea ===" && sudo systemctl status gitea --no-pager | head -5
```

All should show: `active (running)`

### Step 47: Verify All Ports are Listening

```bash
# Check all required ports
echo "Checking listening ports..."
sudo ss -tlnp | grep -E '9090|9100|3000|8080'
```

**Expected output:**
```
LISTEN 0 0 127.0.0.1:9090 0.0.0.0:* users:(("prometheus",pid=XXXX,fd=X))
LISTEN 0 0 127.0.0.1:9100 0.0.0.0:* users:(("node_exporte",pid=XXXX,fd=X))
LISTEN 0 0 0.0.0.0:3000 0.0.0.0:* users:(("grafana-server",pid=XXXX,fd=X))
LISTEN 0 0 0.0.0.0:8080 0.0.0.0:* users:(("cadvisor",pid=XXXX,fd=X))
```

### Step 48: Test Service Connectivity

```bash
# Test Prometheus
echo "Testing Prometheus..."
curl -s http://localhost:9090/-/healthy
echo -e "\n"

# Test Node Exporter
echo "Testing Node Exporter..."
curl -s http://localhost:9100/metrics | head -3
echo -e "\n"

# Test Grafana
echo "Testing Grafana..."
curl -s http://localhost:3000/api/health | python3 -m json.tool
echo -e "\n"

# Test Gitea
echo "Testing Gitea..."
curl -s http://localhost:3000/ | head -5
```

**Expected output:** All return data successfully

### Step 49: Verify Prometheus is Scraping

```bash
# Give services 10 seconds to start scraping
sleep 10

# Query Prometheus for targets
curl -s 'http://localhost:9090/api/v1/query?query=up' | python3 -m json.tool

# Or open in browser: http://localhost:9090/targets
```

**Expected output:** Should show targets with value 1 (up)

---

## Access & Configuration

### Step 50: Get Your Server IP

```bash
# Find server IP
hostname -I

# Or more detailed
ip addr | grep 'inet ' | grep -v '127.0'
```

**Note this IP for accessing from other machines**

### Step 51: Access Grafana Web Interface

1. Open browser to: `http://localhost:3000`
   - Username: `admin`
   - Password: `admin`

2. **IMMEDIATELY change the password:**
   - Click profile icon (top right)
   - Click **Change password**
   - Enter new strong password
   - Click **Change Password**

### Step 52: Add Prometheus as Data Source

1. In Grafana, go to: **Configuration** (⚙️ icon)
2. Click: **Data Sources**
3. Click: **Add data source**
4. Select: **Prometheus**
5. Fill in:
   - Name: `Prometheus`
   - URL: `http://localhost:9090`
   - Leave other settings as default
6. Click: **Save & Test**
7. Should see: **"Data source is working"** (green message)

### Step 53: Import Dashboard #1860 (Node Exporter Full)

1. In Grafana, click: **+ (Create)** → **Import**
2. Under "Import via grafana.com":
   - Paste ID: `1860`
   - Click: **Load**
3. Select Prometheus data source: **Prometheus**
4. Click: **Import**
5. Dashboard should load with system metrics

### Step 54: Import Dashboard #11074 (Alternative Node Exporter)

1. Click: **+ (Create)** → **Import**
2. Paste ID: `11074`
3. Click: **Load**
4. Select Prometheus: **Prometheus**
5. Click: **Import**

### Step 55: Import Dashboard #3662 (Prometheus)

1. Click: **+ (Create)** → **Import**
2. Paste ID: `3662`
3. Click: **Load**
4. Select Prometheus: **Prometheus**
5. Click: **Import**

### Step 56: View Prometheus Targets

1. Open browser: `http://localhost:9090/targets`
2. All targets should show **green "UP"**
3. If any show **red "DOWN"**:
   - Check service is running
   - Check port is listening
   - Check Prometheus configuration

### Step 57: Test a Prometheus Query

1. Open browser: `http://localhost:9090/graph`
2. In the query box, type: `up`
3. Click: **Execute**
4. Should see graph with values
5. Try other queries:
   - `node_cpu_seconds_total`
   - `node_memory_MemAvailable_bytes`
   - `prometheus_http_requests_total`

---

## Firewall Setup

### Step 58: Configure UFW Firewall (if enabled)

```bash
# Check if UFW is enabled
sudo ufw status

# If not enabled, enable it
sudo ufw enable

# Allow SSH (critical!)
sudo ufw allow 22/tcp

# Allow Prometheus
sudo ufw allow 9090/tcp

# Allow Grafana (main access point)
sudo ufw allow 3000/tcp

# Allow Node Exporter
sudo ufw allow 9100/tcp

# Allow cAdvisor (if installed)
sudo ufw allow 8080/tcp

# Verify rules
sudo ufw status numbered
```

**Expected output:** All ports listed as ALLOW

### Step 59: Test Remote Access

From another machine on your network:

```bash
# Get your server IP
# Use IP from Step 50

# Test Grafana
curl http://YOUR_SERVER_IP:3000/api/health

# Test Prometheus
curl http://YOUR_SERVER_IP:9090/-/healthy

# Open in browser:
# http://YOUR_SERVER_IP:3000
```

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: Service won't start

**Symptom:** `systemctl status prometheus` shows failed

**Solution:**
```bash
# Check logs
sudo journalctl -u prometheus -n 30

# Check if port is in use
sudo ss -tlnp | grep 9090

# Check config syntax
sudo -u prometheus /usr/local/bin/promtool check config /etc/prometheus/prometheus.yml

# Check permissions
sudo ls -la /etc/prometheus/
sudo ls -la /var/lib/prometheus/

# Fix if needed
sudo chown -R prometheus:prometheus /etc/prometheus
sudo chown -R prometheus:prometheus /var/lib/prometheus

# Restart
sudo systemctl restart prometheus
```

---

#### Issue 2: Port already in use

**Symptom:** "Address already in use" error

**Solution:**
```bash
# Find what's using the port
sudo lsof -i :3000

# Kill the process (if not needed)
sudo kill -9 PID

# Or use a different port:
sudo nano /etc/grafana/grafana.ini
# Find: http_port = 3000
# Change to: http_port = 3001
# Save and restart
sudo systemctl restart grafana-server
```

---

#### Issue 3: Prometheus targets showing DOWN

**Symptom:** Red "DOWN" status in http://localhost:9090/targets

**Solution:**
```bash
# Check if service is running
sudo systemctl status node_exporter

# Check if port is listening
sudo ss -tlnp | grep 9100

# Check connectivity
curl http://localhost:9100/metrics

# If not working, restart
sudo systemctl restart node_exporter

# Check Prometheus logs
sudo journalctl -u prometheus -n 20
```

---

#### Issue 4: Grafana can't connect to Prometheus

**Symptom:** "Unable to connect to Prometheus" error in Grafana

**Solution:**
```bash
# Verify Prometheus is running
curl http://localhost:9090/-/healthy

# In Grafana:
# 1. Go to Configuration → Data Sources
# 2. Click Prometheus
# 3. Change URL from http://prometheus:9090 to http://localhost:9090
# 4. Click Save & Test

# Check firewall
sudo ufw status | grep 9090

# If not allowed, add it
sudo ufw allow 9090/tcp
```

---

#### Issue 5: High disk usage

**Symptom:** `/var/lib/prometheus/` is very large

**Solution:**
```bash
# Check size
du -sh /var/lib/prometheus/

# Prometheus already limited to 30 days in config
# To manually clean:
sudo systemctl stop prometheus
sudo rm -rf /var/lib/prometheus/wal/*
sudo rm -rf /var/lib/prometheus/wal/checkpoint-*
sudo systemctl start prometheus
```

---

#### Issue 6: No data in dashboards

**Symptom:** Dashboards show "No data"

**Solution:**
```bash
# Verify metrics are being collected
curl 'http://localhost:9090/api/v1/query?query=up'

# Try a simple query in Prometheus
# http://localhost:9090/graph
# Type: up
# Should show results

# Check that services have been running for >1 minute
sudo systemctl status node_exporter

# Re-import dashboard 1860:
# Grafana → + Import → ID: 1860 → Import
```

---

### Checking Service Logs

```bash
# View Prometheus logs (last 50 lines)
sudo journalctl -u prometheus -n 50

# View Node Exporter logs
sudo journalctl -u node_exporter -n 50

# View Grafana logs
sudo journalctl -u grafana-server -n 50

# View Gitea logs
sudo journalctl -u gitea -n 50

# View logs in real-time (follow)
sudo journalctl -u prometheus -f

# Stop following: Ctrl+C
```

---

## Cleanup of Downloaded Files

After installation is complete, you can clean up temporary files:

```bash
# Remove downloaded archives
rm -f /tmp/prometheus-*.tar.gz
rm -f /tmp/node_exporter-*.tar.gz
rm -f /tmp/cadvisor
rm -f /tmp/gitea-*
rm -f /tmp/act_*

# Verify cleanup
ls -la /tmp/
```

---

## Useful Commands for Daily Use

```bash
# Check all services status
sudo systemctl status prometheus node_exporter grafana-server gitea

# Stop all services
sudo systemctl stop prometheus node_exporter grafana-server gitea

# Start all services
sudo systemctl start prometheus node_exporter grafana-server gitea

# Restart all services
sudo systemctl restart prometheus node_exporter grafana-server gitea

# View real-time logs (Prometheus)
sudo journalctl -u prometheus -f

# View real-time logs (Grafana)
sudo journalctl -u grafana-server -f

# Check disk usage
df -h
du -sh /var/lib/prometheus/
du -sh /var/lib/grafana/

# Check memory usage
free -h
ps aux | grep -E 'prometheus|grafana|node_exporter'
```

---

## Summary of Installed Components

| Component | Port | URL | Status Command |
|-----------|------|-----|-----------------|
| **Prometheus** | 9090 | http://localhost:9090 | `systemctl status prometheus` |
| **Grafana** | 3000 | http://localhost:3000 | `systemctl status grafana-server` |
| **Node Exporter** | 9100 | http://localhost:9100/metrics | `systemctl status node_exporter` |
| **Gitea** | 3000 | http://localhost:3000 | `systemctl status gitea` |
| **cAdvisor** | 8080 | http://localhost:8080 | `systemctl status cadvisor` |
| **Act Runner** | N/A | N/A | `systemctl status act_runner` |

---

## What's Next?

1. **Configure Alerting** - Set up alert rules in Prometheus
2. **Backup Configuration** - Backup Prometheus and Grafana configs
3. **Add More Dashboards** - Import more dashboards from grafana.com
4. **Create Custom Dashboards** - Build dashboards for your specific needs
5. **Setup SSL/TLS** - Use Nginx reverse proxy with HTTPS
6. **Monitor More Services** - Add more exporters (MySQL, PostgreSQL, etc.)

---

## Getting Help

1. **Check logs first:**
   ```bash
   sudo journalctl -u <service-name> -f
   ```

2. **Verify configuration:**
   ```bash
   sudo -u prometheus /usr/local/bin/promtool check config /etc/prometheus/prometheus.yml
   ```

3. **Test connectivity:**
   ```bash
   curl http://localhost:9090/-/healthy
   ```

4. **Official Resources:**
   - Prometheus: https://prometheus.io/docs/
   - Grafana: https://grafana.com/docs/
   - Node Exporter: https://github.com/prometheus/node_exporter
   - Gitea: https://docs.gitea.io/

---

## Installation Checklist

Use this to verify you've completed all steps:

- [ ] Step 1-2: System updated
- [ ] Step 3-16: Prometheus installed & running
- [ ] Step 17-22: Node Exporter installed & running
- [ ] Step 23-26: Grafana installed & running
- [ ] Step 27-36: Gitea installed & metrics enabled
- [ ] Step 37-41: (Optional) Act Runner installed
- [ ] Step 42-45: (Optional) cAdvisor installed
- [ ] Step 46-49: All services verified
- [ ] Step 50-57: Grafana configured with dashboards
- [ ] Step 58-59: Firewall configured
- [ ] Troubleshooting: Tested error handling

---

**Congratulations! Your monitoring stack is now fully operational.** 🎉

Start monitoring your infrastructure at: `http://localhost:3000`

Default credentials: `admin` / `admin` (change immediately!)

---

## Quick Reference: Most Used Commands

```bash
# Check all running services
sudo systemctl list-units --type=service | grep -E 'prometheus|grafana|node_exporter|gitea'

# View all listening ports
sudo ss -tlnp

# Check system resources
free -h && df -h

# Restart all services
for service in prometheus node_exporter grafana-server gitea; do sudo systemctl restart $service; done

# Test all endpoints
for port in 9090 9100 3000 8080; do echo "Testing port $port:" && curl -s http://localhost:$port/metrics 2>&1 | head -1; done
```

---

**Last Updated:** Ubuntu 25.04 | Prometheus 2.48.0 | Grafana Latest | Node Exporter 1.7.0

---