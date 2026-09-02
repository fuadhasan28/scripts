You are a Senior Linux DevOps Engineer, Bash Automation Specialist, and Infrastructure Architect.

IMPORTANT

Follow AGENTS.md throughout the entire task.

The goal is NOT merely to install Gitea.

The goal is to create a production-ready, user-friendly Bash installation script that automates the deployment of Gitea on a Linux server.

Before writing any code:

1. Analyze all requirements.
2. Create a detailed phase-by-phase implementation plan.
3. Identify edge cases.
4. Identify dependency requirements.
5. Design the interactive workflow.
6. Explain your design decisions.
7. Then generate the final script.

---

## OBJECTIVE

Generate a complete Bash script that installs and configures Gitea.

Cloudflare configuration is OUT OF SCOPE and should NOT be included.

---

## INTERACTIVE SETUP REQUIREMENTS

The script must be fully interactive.

---

STEP 1
INSTANCE POSTFIX

---

Ask the user:

Enter a postfix for this Gitea instance:

Example:

stage
prod
dev
uat

If user enters:

stage

Then automatically derive:

Site Name:
gitea_stage

Install Directory:
gitea_stage

Service Name:
gitea_stage.service

Configuration Paths:
gitea_stage based

Use the postfix consistently everywhere.

---

STEP 2
PORT SELECTION

---

The installer must scan the system and find a random available port.

Present:

Suggested Available Port: XXXX

Options:

1. Yes (use suggested port)
2. No (search another available port)
3. Custom

If Custom:

- Ask user for a port.
- Validate port range.
- Check whether port is already in use.
- If occupied:
  - Show an error.
  - Ask again.
- Repeat until a valid available port is provided.

---

STEP 3
HOST TYPE

---

Ask:

Will Gitea run on:

1. Domain
2. IP Address

If Domain:

Ask for:

- Domain Name

Validate input format.

If IP:

Ask for:

- IP Address

Validate IP format.

---

STEP 4
DATABASE

---

Ask:

Database Type

1. SQLite
2. MySQL

If SQLite:

Proceed automatically.

If MySQL:

Ask for:

- Database Host
- Database Port
- Database Name
- Database Username
- Database Password

Validate required fields.

Configure Gitea accordingly.

---

## DEPLOYMENT REQUIREMENTS

The script must automatically:

- Update package indexes if needed.
- Install required dependencies.
- Download latest stable Gitea release.
- Create required directories.
- Set ownership.
- Set permissions.
- Create configuration files.
- Create systemd service.
- Enable service.
- Start service.
- Reload daemon if needed.
- Perform validation checks.

---

## USER REQUIREMENT

Use:

www-data

as the service account.

All folders and files must be owned accordingly.

---

## DIRECTORY STRUCTURE

Design an organized structure.

Example:

/opt/gitea_stage
/etc/gitea_stage
/var/lib/gitea_stage
/var/log/gitea_stage

or a better structure if required.

Explain why your structure is chosen.

---

## GITEA CONFIGURATION

Generate all required configuration.

Configure:

- Server Settings
- Repository Storage
- Database Settings
- Logging
- App URL
- Domain/IP Handling
- Service Account
- Security Defaults

Use secure defaults whenever possible.

---

## SERVICE CONFIGURATION

Generate a proper systemd service.

Service should:

- Auto restart
- Start on boot
- Run as www-data

Validate the service after creation.

---

## SCRIPT QUALITY REQUIREMENTS

The script should:

- Be idempotent whenever possible.
- Validate prerequisites.
- Validate user inputs.
- Handle failures gracefully.
- Use readable functions.
- Include comments.
- Use colorized output.

---

## USER EXPERIENCE

Console output must clearly show:

[STEP 1/10]
[STEP 2/10]

etc.

Use colors.

Display:

- Current task
- Success messages
- Warning messages
- Error messages

The user should always understand:

- What is happening
- Why it is happening
- What the script is currently doing

---

## CLEANUP

At the end:

Remove temporary files.

Remove installation garbage.

Keep only required runtime files.

---

## FINAL OUTPUT

After successful completion display:

Service Name
(in a distinct color)

Service File Path
(in a distinct color)

Configuration File Path
(in a distinct color)

Install Directory
(in a distinct color)

Runtime Port
(in a distinct color)

Domain or IP
(in a distinct color)

Useful Commands:

- systemctl status
- restart
- stop
- logs

---

## PRE-CODE TASKS

Before generating the Bash script:

Provide:

1. Requirement Analysis
2. Phase-by-Phase Plan
3. Directory Structure Design
4. Service Design
5. Security Considerations
6. Port Selection Strategy
7. Database Strategy
8. Risk Analysis

Then generate the complete production-ready Bash script.

The final script should be ready to run on a clean Linux server and should require minimal manual intervention.
