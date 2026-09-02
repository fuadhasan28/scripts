# Execution & Rollback Log: nsGit Server Monitoring Setup (`172.16.229.55`)

**Server**: `172.16.229.55` (nsGit)  
**User**: `nsgit`  
**OS**: Ubuntu 24.04.4 LTS  
**Strategy**: Node Exporter only on nsGit. Grafana and Prometheus run on `10.112.165.132`, scraping nsGit remotely.

> [!WARNING]
> This is a **production server**. Only minimal required software (Node Exporter) will be installed.
> No Grafana, Prometheus, or alertmanager will be installed on this server.

---

## Environment Discovery (Pre-Install)

| Property | Value |
| :--- | :--- |
| Hostname | `srv-gitea` |
| IP | `172.16.229.55` |
| OS | Ubuntu 24.04.4 LTS |
| RAM | 251 GB |
| Disk | 15 TB total, 3% used |
| Port 9090 | Occupied by `cockpit-tls` |
| Port 3000 | Occupied by `gitea` |
| Port 9100 | **FREE** (assigned to Node Exporter) |
| `gitea-prod.service` | Active & Running |
| Pre-existing monitoring | None |

---

## Log Entries

| Timestamp (ISO) | Action | Target / Files | Undo / Rollback Command | Status |
| :--- | :--- | :--- | :--- | :--- |
| `2026-09-02T19:41:10+06:00` | Environment diagnostic via SSH | `172.16.229.55` | N/A (Read-only) | ✅ SUCCESS |
| `2026-09-02T19:42:00+06:00` | Installed Node Exporter v1.7.0 | `/usr/local/bin/node_exporter` | `rm /usr/local/bin/node_exporter` | ✅ SUCCESS |
| `2026-09-02T19:42:05+06:00` | Created node_exporter systemd service | `/etc/systemd/system/node_exporter.service` | `systemctl disable --now node_exporter && rm /etc/systemd/system/node_exporter.service` | ✅ SUCCESS |
| `2026-09-02T19:42:07+06:00` | Enabled & started node_exporter | `systemctl enable --now node_exporter` | `systemctl disable --now node_exporter` | ✅ SUCCESS |
| `2026-09-02T19:43:10+06:00` | Backed up prometheus.yml on 10.112.165.132 | `/etc/prometheus/prometheus.yml.bak.nsgit` | N/A (backup) | ✅ SUCCESS |
| `2026-09-02T19:43:15+06:00` | Added `nsgit_node` scrape job to prometheus.yml | `/etc/prometheus/prometheus.yml` | Restore backup: `cp /etc/prometheus/prometheus.yml.bak.nsgit /etc/prometheus/prometheus.yml` | ✅ SUCCESS |
| `2026-09-02T19:43:53+06:00` | Restarted Prometheus to pick up new target | `prometheus.service` on `10.112.165.132` | N/A | ✅ SUCCESS |
| `2026-09-02T19:45:19+06:00` | Created Grafana folder `nsGit Server` | Grafana API | Delete via Grafana UI or API | ✅ SUCCESS |
| `2026-09-02T19:45:19+06:00` | Created Grafana dashboard `nsgit-monitoring-v1` | Grafana API | Delete via Grafana UI or API | ✅ SUCCESS |
| `2026-09-02T19:47:45+06:00` | Fixed datasource UID in dashboard to `PBFA97CFB590B2093` | Grafana dashboard JSON | N/A | ✅ SUCCESS |
| `2026-09-02T20:11:37+06:00` | Provisioned Telegram contact point `telegram-nsgit-alerts` | Grafana Alerting API | Delete contact point | ✅ SUCCESS |
| `2026-09-02T20:11:42+06:00` | Updated default notification policy to route to Telegram | Grafana Policy API | Reset notification policy | ✅ SUCCESS |
| `2026-09-02T20:12:00+06:00` | Created 5 nsGit Alert Rules in `nsGit Server` / `nsgit-alerts` | Grafana Provisioning API | Delete alert rules | ✅ SUCCESS |
| `2026-09-02T20:31:00+06:00` | Linked Telegram Chat ID `1894888246` (@fuad_the_panda) & updated contact point | Grafana Alerting API | Update chat ID | ✅ SUCCESS |
| `2026-09-02T20:31:10+06:00` | Configured dual notification policy routing to BOTH Telegram and MQTT | Grafana Policy API | Reset policy | ✅ SUCCESS |
| `2026-09-02T20:32:40+06:00` | Triggered test notifications from Grafana UI for Telegram & MQTT | Grafana Alertmanager | N/A | ✅ SUCCESS |

---

## Final Verification

| Check | Result |
| :--- | :--- |
| Node Exporter listening on `:9100` | ✅ Confirmed |
| `gitea-prod.service` metrics visible | ✅ Confirmed (`node_systemd_unit_state{name="gitea-prod.service",state="active"} 1`) |
| Prometheus scraping `172.16.229.55:9100` | ✅ Target health = `up` |
| Grafana dashboard populated (0 errors) | ✅ All panels showing live data |
| gitea-prod.service shows RUNNING (green) | ✅ Confirmed |
| Grafana Alert Rules Evaluation | ✅ 5/5 rules provisioned and in Normal state |

---

## Rollback Instructions (If Needed)

### Remove Node Exporter from nsGit
```bash
sudo systemctl disable --now node_exporter
sudo rm /etc/systemd/system/node_exporter.service
sudo rm /usr/local/bin/node_exporter
sudo systemctl daemon-reload
```

### Remove nsGit scrape from Prometheus (on 10.112.165.132)
```bash
sudo cp /etc/prometheus/prometheus.yml.bak.nsgit /etc/prometheus/prometheus.yml
sudo systemctl restart prometheus
```

### Remove Grafana Dashboard
```bash
curl -X DELETE http://10.112.165.132:3002/api/dashboards/uid/nsgit-monitoring-v1 \
  -H "Authorization: Basic $(echo -n 'admin:nopTraining@2026#' | base64)"
```
