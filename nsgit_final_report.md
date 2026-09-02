# nsGit Server Monitoring — Final Task Report

**Prepared for**: Replicable deployment reference  
**Date**: 2026-09-02  
**Author**: Antigravity (AI Agent)  
**Target Server**: `172.16.229.55` (nsGit / srv-gitea)  
**Monitoring Host**: `10.112.165.132` (nopTraining — hosts Prometheus + Grafana)

---

## 🎯 Goal

Monitor the `nsGit` production server remotely with minimal installation:
- Install **only Node Exporter** on nsGit (port `9100`)
- Use the **existing Prometheus** on `10.112.165.132:9091` to scrape metrics remotely
- Use the **existing Grafana** on `10.112.165.132:3002` to display dashboards
- Monitor **server resources** (CPU, RAM, Disk, Network) and specifically **`gitea-prod.service`**

---

## Architecture

```
nsGit (172.16.229.55)
  └── [NEW] Node Exporter :9100
        └── /metrics <- Prometheus scrapes this

nopTraining (10.112.165.132)
  ├── Prometheus :9091 <- scrapes 172.16.229.55:9100
  └── Grafana :3002   <- queries Prometheus
```

> [!IMPORTANT]
> Both servers are on the same internal network, so remote scraping works without VPN tunnels.

---

## Pre-requisites (What to Check First)

Before replicating on a new server, verify:

- Port `9100` is **free** on the target server: `ss -tlnp | grep 9100`
- Target server user has sudo access
- The service you want to monitor exists: `systemctl status <service-name>`
- Both servers can reach each other (test: `curl http://TARGET_IP:9100/metrics` from Prometheus host)

---

## Step 1 — Install Node Exporter on Target Server

### 1a. Create system user

```bash
sudo useradd --no-create-home --shell /bin/false node_exporter
```

### 1b. Download and install

```bash
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xfz node_exporter-1.7.0.linux-amd64.tar.gz
sudo cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
sudo chmod +x /usr/local/bin/node_exporter
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
rm -rf /tmp/node_exporter-1.7.0.linux-amd64*
```

### 1c. Create systemd service

Replace `YOUR_SERVICE_NAME` with the actual service (e.g., `gitea-prod.service`):

```bash
sudo tee /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/node_exporter \
  --collector.systemd \
  --collector.systemd.unit-include="YOUR_SERVICE_NAME|node_exporter\.service"

Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
```

For `nsGit` we used:
```
--collector.systemd.unit-include="gitea.*\.service|node_exporter\.service"
```

> [!NOTE]
> The `--collector.systemd` flag enables systemd service state tracking.
> The `--collector.systemd.unit-include` value is a **Go regex**.
> Dots in service names must be escaped with a backslash: `gitea-prod\.service`

### 1d. Enable and start

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
```

### 1e. Verify metrics

```bash
# Check listening port
sudo ss -tlnp | grep 9100

# Check service is tracked (replace gitea with your service name)
curl http://localhost:9100/metrics | grep node_systemd_unit_state
```

Expected output:
```
node_systemd_unit_state{name="gitea-prod.service",state="active",type="simple"} 1
```

---

## Step 2 — Configure Prometheus (on 10.112.165.132)

### 2a. Backup existing config

```bash
sudo cp /etc/prometheus/prometheus.yml /etc/prometheus/prometheus.yml.bak.$(date +%Y%m%d)
```

### 2b. Add scrape job (append to prometheus.yml)

```bash
sudo tee -a /etc/prometheus/prometheus.yml << 'EOF'

  - job_name: 'nsgit_node'
    static_configs:
      - targets: ['172.16.229.55:9100']
        labels:
          server: 'nsGit'
          alias: 'Gitea Production Server'
EOF
```

> [!TIP]
> Always add `server` and `alias` labels so you can filter by server name in Grafana dashboards.

### 2c. Validate and restart

```bash
promtool check config /etc/prometheus/prometheus.yml
sudo systemctl restart prometheus
```

### 2d. Verify target is UP

```bash
curl -s http://localhost:9091/api/v1/targets | python3 -c "
import json, sys
data = json.load(sys.stdin)
for t in data['data']['activeTargets']:
    print(t['labels'].get('job'), '|', t['health'], '|', t['labels'].get('instance'))
"
```

Expected:
```
nsgit_node | up | 172.16.229.55:9100
```

---

## Step 3 — Create Grafana Dashboard

### Dashboard: nsGit Server Monitoring

The dashboard was created via Grafana API with the following panels:

| Panel | Type | Description |
| :--- | :--- | :--- |
| gitea-prod.service Status | Stat | Green=RUNNING, Red=DOWN |
| Server Uptime | Stat | Human-readable uptime |
| CPU Usage % | Stat + Timeseries | 5-minute rolling average |
| RAM Usage % | Stat + Timeseries | Available vs Total |
| Disk Usage % | Stat | Root mount point |
| Network I/O | Timeseries | RX/TX bytes per second |
| Disk I/O | Timeseries | Read/Write bytes per second |
| Services State Table | Table | All monitored systemd units |
| Service History | Timeseries | 1 = up, 0 = down over time |

### Key PromQL Queries

```promql
# gitea-prod.service active state
node_systemd_unit_state{job="nsgit_node",name="gitea-prod.service",state="active"}

# CPU Usage %
100 - (avg by(instance)(rate(node_cpu_seconds_total{job="nsgit_node",mode="idle"}[5m])) * 100)

# RAM Usage %
(1 - node_memory_MemAvailable_bytes{job="nsgit_node"} / node_memory_MemTotal_bytes{job="nsgit_node"}) * 100

# Disk Usage %
(1 - node_filesystem_avail_bytes{job="nsgit_node",mountpoint="/"} / node_filesystem_size_bytes{job="nsgit_node",mountpoint="/"}) * 100

# Network RX
rate(node_network_receive_bytes_total{job="nsgit_node",device!="lo"}[5m])

# Server Uptime (seconds)
node_time_seconds{job="nsgit_node"} - node_boot_time_seconds{job="nsgit_node"}
```

---

## Final Verification Checklist

| Check | Command | Expected |
| :--- | :--- | :--- |
| Node Exporter running | `systemctl status node_exporter` | `active (running)` |
| Metrics port open | `ss -tlnp | grep 9100` | `LISTEN *:9100` |
| Service tracked | `curl localhost:9100/metrics | grep gitea-prod` | `state="active"} 1` |
| Prometheus target UP | Prometheus API targets | `nsgit_node | up` |
| Grafana dashboard | http://10.112.165.132:3002/d/nsgit-monitoring-v1/ | All panels with live data |

---

## Replicating on a Future Server

To add monitoring for **any new server** (`NEW_SERVER_IP`):

1. SSH into `NEW_SERVER_IP` and run Steps 1a-1e
   - Adjust `--collector.systemd.unit-include` for the services you need
2. On `10.112.165.132`, add a new scrape job in prometheus.yml (Step 2a-2d)
   - Use a **unique** `job_name` (e.g., `myserver_node`)
3. Create a new Grafana dashboard — copy the query table above and:
   - Replace `job="nsgit_node"` with `job="myserver_node"` everywhere
   - Change the dashboard `uid` and `title`

---

## Rollback Instructions

### Remove Node Exporter from nsGit

```bash
sudo systemctl disable --now node_exporter
sudo rm /etc/systemd/system/node_exporter.service
sudo rm /usr/local/bin/node_exporter
sudo systemctl daemon-reload
```

### Remove nsGit from Prometheus

```bash
# On 10.112.165.132:
sudo cp /etc/prometheus/prometheus.yml.bak.nsgit /etc/prometheus/prometheus.yml
sudo systemctl restart prometheus
```

### Remove Grafana Dashboard

```bash
curl -X DELETE http://10.112.165.132:3002/api/dashboards/uid/nsgit-monitoring-v1 \
  -H "Authorization: Basic $(echo -n 'admin:nopTraining@2026#' | base64)"
```

---

## Access Points

| Service | URL |
| :--- | :--- |
| Grafana — nsGit Dashboard | http://10.112.165.132:3002/d/nsgit-monitoring-v1/ |
| Prometheus Targets Page | http://10.112.165.132:9091/targets |
| nsGit Node Exporter Metrics | http://172.16.229.55:9100/metrics |
