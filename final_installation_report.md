# Complete Bare-Metal Monitoring Stack Setup Report

**Target Host**: `10.112.165.132`  
**User Account**: `noptraining`  
**OS**: Ubuntu 22.04.5 LTS  
**Installed Services**: Prometheus (`:9091`), Node Exporter (`:9100`), Grafana (`:3002`)

---

## 1. Port Exclusion & Mapping Matrix

| Service / App | Assigned Port | Status | Notes |
| :--- | :--- | :--- | :--- |
| **Port 3000** | Reserved | SKIPPED | Reserved for internal applications |
| **Port 3001** | Reserved | SKIPPED | Used by Uptime Kuma (`uptime-kuma`) |
| **Port 5000** | Reserved | SKIPPED | Reserved for internal applications |
| **Port 9090** | Reserved | SKIPPED | Used by systemd socket activation |
| **Prometheus** | **`9091`** | **HEALTHY** | Scraping Prometheus (`:9091`), Node Exporter (`:9100`), Grafana (`:3002`) |
| **Node Exporter** | **`9100`** | **HEALTHY** | Exposing OS, CPU, Memory, Disk, and Network metrics |
| **Grafana OSS** | **`3002`** | **HEALTHY** | Web UI Dashboard (`http://10.112.165.132:3002`) |

---

## 2. Step-by-Step Installation & Configuration Guide

### Step 1: System Preparation & User Creation
```bash
# Create dedicated non-login system users
sudo useradd --no-create-home --shell /bin/false prometheus 2>/dev/null || true
sudo useradd --no-create-home --shell /bin/false node_exporter 2>/dev/null || true

# Create required configuration and data directories
sudo mkdir -p /etc/prometheus /var/lib/prometheus /var/lib/grafana
```

### Step 2: Node Exporter Installation (Port 9100)
```bash
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xfz node_exporter-1.7.0.linux-amd64.tar.gz
sudo cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
sudo chmod +x /usr/local/bin/node_exporter
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Create systemd unit file (/etc/systemd/system/node_exporter.service)
sudo bash -c 'cat << EOF > /etc/systemd/system/node_exporter.service
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

[Install]
WantedBy=multi-user.target
EOF'
```

### Step 3: Prometheus Installation (Port 9091)
```bash
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v2.48.0/prometheus-2.48.0.linux-amd64.tar.gz
tar xfz prometheus-2.48.0.linux-amd64.tar.gz
sudo cp prometheus-2.48.0.linux-amd64/prometheus /usr/local/bin/
sudo cp prometheus-2.48.0.linux-amd64/promtool /usr/local/bin/
sudo cp -r prometheus-2.48.0.linux-amd64/consoles /etc/prometheus/
sudo cp -r prometheus-2.48.0.linux-amd64/console_libraries /etc/prometheus/

# Create Prometheus Configuration (/etc/prometheus/prometheus.yml)
sudo bash -c 'cat << EOF > /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: []

rule_files: []

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9091"]

  - job_name: "node"
    static_configs:
      - targets: ["localhost:9100"]

  - job_name: "grafana"
    static_configs:
      - targets: ["localhost:3002"]
    metrics_path: "/metrics"
EOF'

sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

# Create Systemd Unit File (/etc/systemd/system/prometheus.service)
sudo bash -c 'cat << EOF > /etc/systemd/system/prometheus.service
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
  --web.listen-address=:9091

Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF'
```

### Step 4: Grafana OSS Installation (Port 3002)
```bash
# Add Grafana repository & keys
sudo rm -f /etc/apt/sources.list.d/grafana*.list
sudo mkdir -p /etc/apt/keyrings
wget -q -O /tmp/grafana.key https://apt.grafana.com/gpg.key
sudo gpg --yes --dearmor -o /etc/apt/keyrings/grafana.gpg /tmp/grafana.key
rm -f /tmp/grafana.key

echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

sudo apt-get update -q
sudo apt-get install -y -q grafana

# Configure Grafana Port to 3002 in /etc/grafana/grafana.ini
sudo cp /etc/grafana/grafana.ini /etc/grafana/grafana.ini.bak
sudo sed -i 's/^;http_port = 3000/http_port = 3002/' /etc/grafana/grafana.ini
sudo sed -i 's/^http_port = 3000/http_port = 3002/' /etc/grafana/grafana.ini
```

### Step 5: Enable and Start Services
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
sudo systemctl enable --now prometheus
sudo systemctl enable --now grafana-server
```

---

## 3. Verification & Testing Commands

```bash
# 1. Check Listening Ports
sudo ss -tlnp | grep -E '9091|9100|3002'

# 2. Test Prometheus Health Endpoint
curl -s http://localhost:9091/-/healthy

# 3. Test Node Exporter Metrics Output
curl -s http://localhost:9100/metrics | head -n 10

# 4. Test Grafana API Health
curl -s http://localhost:3002/api/health
```

**Expected Output for Grafana Health**:
```json
{
  "database": "ok",
  "version": "13.2.0",
  "commit": "f681b1359f6a0b8ecb9f2c49a88ac72b75bde73b"
}
```

---

## 4. Access URLs & Login Credentials

- **Grafana Web Dashboard**: [`http://10.112.165.132:3002`](http://10.112.165.132:3002)
  - **Username**: `admin`
  - **Password**: `nopTraining@2026#`
  - **Pre-configured Data Source**: Prometheus (`http://localhost:9091`)
  - **Pre-loaded Dashboard**: Node Exporter Full ([`/d/rYdddlPWk/node-exporter-full`](http://10.112.165.132:3002/d/rYdddlPWk/node-exporter-full))
- **Prometheus Metrics Web UI**: [`http://10.112.165.132:9091`](http://10.112.165.132:9091)
- **Node Exporter Metrics Output**: [`http://10.112.165.132:9100/metrics`](http://10.112.165.132:9100/metrics)
