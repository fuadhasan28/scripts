# Antigravity Workspace Rules for DevOps and Scripting

## General Guidelines
- Ensure all Bash scripts are thoroughly tested, have adequate logging, and handle edge cases gracefully (e.g., using `set -e`).
- Always follow the principle of least privilege. Do not run `sudo` without confirming with the user unless explicitly stated otherwise.
- Avoid modifying operating system files or pre-existing production configuration files without creating backups first.
- Maintain accurate and comprehensive logs in `work_log.md` for any deployment, monitoring setup, or structural change.
- When configuring ports or networks, double-check port availability before assigning standard ports (e.g., ports `3000`, `9090`).

## Documentation Requirements
- Keep `walkthrough.md` updated after the completion of major setup milestones.
- Ensure all custom commands or complex `ss`, `ps`, and `netstat` commands used for troubleshooting are documented within the corresponding walkthroughs or `work_log.md`.
- Read credentials carefully from `server_credentials.md` or `docs/task_desc/credentials.md` and confirm targets before remote SSH operations.
