---
name: server-monitoring
description: >-
  Use this skill when the user asks to setup, troubleshoot, or configure server monitoring stacks involving Prometheus, Grafana, Node Exporter, or cAdvisor.
---

# Server Monitoring & DevOps Skill

Provide structured, safe, and reproducible steps when managing server monitoring tools.

## Setup Requirements
1. **Port Constraints**: Always verify if default ports (`3000` for Grafana, `9090` for Prometheus, `9100` for Node Exporter) are available before applying standard configurations.
2. **Permissions**: Do not execute destructive commands (like `rm -rf`, `apt remove`, or `systemctl stop`) without explicit user permission.
3. **Reproducibility**: Ensure all configurations are logged so that the setup can be reproduced on other staging or production servers.

## Verification Steps
- Verify services are running with `systemctl status <service>`.
- Check if ports are listening with `ss -tlnp`.
- Test metric endpoints with `curl -s http://localhost:<port>/metrics`.
- Test UI accessibility with `curl -s http://localhost:<port>/api/health` (for Grafana) or `/-/healthy` (for Prometheus).
