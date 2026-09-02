# Comprehensive Monitoring & Alerting Guide (Grafana, Prometheus & Node Exporter)

**Target Server**: `10.112.165.132`  
**Installed Stack**: Prometheus (`:9091`), Node Exporter (`:9100`), Grafana (`:3002`)

---

## 1. Overview

This guide explains how to configure, customize, and extend your monitoring stack to track both overall server health (CPU, RAM, Disk, Network) and specific systemd services (e.g., `cloudflared_nopstation_site.service`).

---

## 2. Service Monitoring with Node Exporter (Systemd Collector)

Node Exporter can monitor individual Linux systemd services using the `--collector.systemd` flag.

### Enabling Service Collector in Node Exporter

Edit `/etc/systemd/system/node_exporter.service`:

```ini
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/node_exporter \
  --collector.systemd \
  --collector.systemd.unit-include="cloudflared.*\.service|prometheus\.service|grafana-server\.service"

Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

Reload and restart Node Exporter:
```bash
sudo systemctl daemon-reload
sudo systemctl restart node_exporter
```

### Useful PromQL Queries for Services

Test these queries in Prometheus (`http://10.112.165.132:9091`):

1. **Check if `cloudflared_nopstation_site.service` is Active** (Returns `1` if running, `0` if down):
   ```promql
   node_systemd_unit_state{name="cloudflared_nopstation_site.service", state="active"}
   ```

2. **Check if any monitored service failed**:
   ```promql
   node_systemd_unit_state{state="failed"} == 1
   ```

---

## 3. Configuring Prometheus Targets (`prometheus.yml`)

Prometheus configuration is stored at `/etc/prometheus/prometheus.yml`.

### Example `prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9091']

  # Server hardware & systemd metrics
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']

  # Grafana metrics
  - job_name: 'grafana'
    static_configs:
      - targets: ['localhost:3002']
    metrics_path: '/metrics'
```

To apply config changes:
```bash
sudo systemctl reload prometheus
# OR check syntax before reload:
sudo promtool check config /etc/prometheus/prometheus.yml
```

---

## 4. Configuring Grafana Web UI (`http://10.112.165.132:3002`)

### Step 4.1: Initial Login
1. Open URL in browser: `http://10.112.165.132:3002`
2. Login with default credentials:
   - **Username**: `admin`
   - **Password**: `admin`
3. Set a new password when prompted.

---

### Step 4.2: Add Prometheus Data Source
1. In Grafana left sidebar, click **Connections** -> **Data Sources**.
2. Click **Add data source**.
3. Select **Prometheus**.
4. Set Connection URL: `http://localhost:9091`
5. Click **Save & test**. You should see a green checkmark indicating successful connection.

---

### Step 4.3: Import Pre-built Node Exporter Dashboard
1. Click **+** (Create) in top right -> **Import dashboard**.
2. Type Dashboard ID `1860` (Official **Node Exporter Full** Dashboard) or `11074`.
3. Click **Load**.
4. Select `Prometheus` as the data source.
5. Click **Import**. You will immediately see real-time graphs for CPU, Memory, Disk I/O, and Network.

---

### Step 4.4: Create Custom Service Monitoring Panel for `cloudflared_nopstation_site.service`
1. Go to your Dashboard and click **Add** -> **Visualization**.
2. Select **Prometheus** as data source.
3. In the query box, enter:
   ```promql
   node_systemd_unit_state{name="cloudflared_nopstation_site.service", state="active"}
   ```
4. On the right panel options:
   - **Visualization Type**: Select **Stat** or **State timeline**.
   - **Title**: `Cloudflare NopStation Site Service`
   - **Value mappings**:
     - `1` -> `UP` (Color: Green)
     - `0` -> `DOWN` (Color: Red)
5. Click **Save** in top right.

---

## 5. Setting Up Service Down Alerts in Grafana

1. In Grafana sidebar, navigate to **Alerting** -> **Alert rules**.
2. Click **Create alert rule**.
3. Set Rule Name: `Cloudflared Service Down`.
4. Enter Query:
   ```promql
   node_systemd_unit_state{name="cloudflared_nopstation_site.service", state="active"} == 0
   ```
5. Set Condition: `Is Above 0` (fires if service state active equals 0 for > 1 minute).
6. Configure Contact Point (Discord, Telegram, Email, Slack, Uptime Kuma webhook).
7. Click **Save & Exit**.

---

## 6. Quick Verification Commands

```bash
# Verify all listening ports
sudo ss -tlnp | grep -E '9091|9100|3002'

# Verify Node Exporter systemd metrics
curl -s http://localhost:9100/metrics | grep "cloudflared_nopstation_site"

# Verify Grafana Status
curl -s http://localhost:3002/api/health
```
