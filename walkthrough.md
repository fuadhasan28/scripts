# Server Monitoring Setup Walkthrough (`10.112.165.132`)

This document summarizes the installation, configuration, port exclusions, and verification of the monitoring stack on **`10.112.165.132`** (`noptraining`).

---

## 1. Port Exclusion & Mapping Matrix

| Service | Target Port | Status | Reason |
| :--- | :--- | :--- | :--- |
| **Port 3000** | Reserved | SKIPPED | Reserved for internal applications |
| **Port 3001** | Reserved | SKIPPED | Used by Uptime Kuma (`uptime-kuma`) |
| **Port 5000** | Reserved | SKIPPED | Reserved for internal applications |
| **Port 9090** | Reserved | SKIPPED | Used by systemd socket activation |
| **Prometheus** | `9091` | ACTIVE | Scraping Node Exporter, Grafana, and itself |
| **Node Exporter** | `9100` | ACTIVE | Server hardware & OS metrics collector |
| **Grafana Server** | `3002` | ACTIVE | Visualisation dashboards UI |

---

## 2. Completed Steps

1. **Service Reset & Cleanup**: Stopped pre-existing unconfigured Prometheus and Node Exporter systemd services.
2. **Directory & User Infrastructure**:
   - Created non-login system users `prometheus` and `node_exporter`.
   - Setup `/etc/prometheus`, `/var/lib/prometheus`, `/var/lib/grafana`.
3. **Node Exporter Deployment**:
   - Downloaded and placed binary `/usr/local/bin/node_exporter`.
   - Created systemd unit `/etc/systemd/system/node_exporter.service`.
4. **Prometheus Deployment**:
   - Downloaded and placed binaries `/usr/local/bin/prometheus` & `/usr/local/bin/promtool`.
   - Created `/etc/prometheus/prometheus.yml` configured to scrape:
     - Prometheus (`localhost:9091`)
     - Node Exporter (`localhost:9100`)
     - Grafana (`localhost:3002`)
   - Created systemd unit `/etc/systemd/system/prometheus.service` bound to `:9091`.
5. **Grafana OSS Deployment**:
   - Resolved GPG keyring issue by adding `https://apt.grafana.com/gpg.key` to `/etc/apt/keyrings/grafana.gpg`.
   - Installed `grafana-server` via `apt`.
   - Updated `/etc/grafana/grafana.ini` to set `http_port = 3002`.
6. **Service Activation & Verification**:
   - Enabled and started `node_exporter`, `prometheus`, and `grafana-server`.
   - Confirmed endpoints via `curl` health checks.

---

## 3. Verification Metrics & Endpoints

- **Grafana Web Interface**: [`http://10.112.165.132:3002`](http://10.112.165.132:3002)
- **Prometheus Web UI**: [`http://10.112.165.132:9091`](http://10.112.165.132:9091)
- **Node Exporter Endpoint**: [`http://10.112.165.132:9100/metrics`](http://10.112.165.132:9100/metrics)

---

## 5. nsGit Remote Monitoring Setup (`172.16.229.55`)

- **Node Exporter**: Running on `172.16.229.55:9100` with `--collector.systemd` monitoring `gitea-prod.service`.
- **Remote Scrape**: Added `nsgit_node` job to `/etc/prometheus/prometheus.yml` on `10.112.165.132`.
- **Grafana Dashboard**: Created `nsGit Server Monitoring` dashboard at [`/d/nsgit-monitoring-v1/nsgit-server-monitoring`](http://10.112.165.132:3002/d/nsgit-monitoring-v1/nsgit-server-monitoring).

---

## 6. Telegram Alerting System

- **Contact Point**: `telegram-nsgit-alerts` configured in Grafana with bot token `8961988358:AAFeLEXzY4JdLjP-bD6mDq9lCsRmRMSMBFg`.
- **Notification Policy**: Default policy routes all alerts to `telegram-nsgit-alerts`.
- **Alert Rules Provisioned (Folder: `nsGit Server` / Group: `nsgit-alerts`)**:
  1. `nsGit: gitea-prod.service Down` (Critical, <1 active for 1m)
  2. `nsGit: Server Unreachable / Down` (Critical, up == 0 for 1m)
  3. `nsGit: High CPU Utilization (>85%)` (Warning, >85% for 5m)
  4. `nsGit: High RAM Utilization (>90%)` (Warning, >90% for 5m)
  5. `nsGit: Low Disk Space (>90% full)` (Warning, >90% for 5m)
- **Status**: All 5 rules active and evaluated in `Normal` state.

---

## 7. Documentation Artifacts Generated

1. [`final_installation_report.md`](file:///c:/001.Data/scripts/scripts/final_installation_report.md): Reproducible guide for deploying the monitoring stack on other servers.
2. [`server_132_monitoring_log.md`](file:///c:/001.Data/scripts/scripts/server_132_monitoring_log.md): Execution & rollback log for server `10.112.165.132`.
3. [`nsgit_monitoring_log.md`](file:///c:/001.Data/scripts/scripts/nsgit_monitoring_log.md): Execution & rollback log for nsGit (`172.16.229.55`).
4. [`nsgit_final_report.md`](file:///c:/001.Data/scripts/scripts/nsgit_final_report.md): Standalone setup & replication guide for nsGit monitoring.
5. [`work_log.md`](file:///c:/001.Data/scripts/scripts/work_log.md): Workspace progress tracking.
