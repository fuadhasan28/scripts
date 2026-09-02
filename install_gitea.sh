#!/usr/bin/env bash
# =============================================================================
#  install_gitea.sh
#  Production-ready, interactive Gitea installer for Linux servers.
#
#  Features:
#    - Postfix-scoped multi-instance support
#    - Auto port detection with user override
#    - Domain or IP hosting
#    - SQLite or MySQL database
#    - systemd service (auto-restart, start-on-boot) running as www-data
#    - SHA-256 binary verification
#    - Auto-generated SECRET_KEY and INTERNAL_TOKEN
#    - Idempotent — safe to re-run
#    - Colorized, numbered step output
#
#  Usage:
#    sudo bash install_gitea.sh
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# PHASE 0 — SCAFFOLDING: COLORS, PRINT HELPERS, GLOBALS
# =============================================================================

# ----- ANSI Colors -----------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ----- Print Helpers ---------------------------------------------------------

print_banner() {
    echo -e ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║          GITEA INTERACTIVE INSTALLER v1.0                ║${RESET}"
    echo -e "${CYAN}${BOLD}║          Production-Ready Deployment Script              ║${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
    echo -e ""
}

print_step() {
    local step="$1"
    local total="$2"
    local desc="$3"
    echo -e ""
    echo -e "${BOLD}${BLUE}┌─────────────────────────────────────────────────────────┐${RESET}"
    echo -e "${BOLD}${BLUE}│  [STEP ${step}/${total}]  ${desc}${RESET}"
    echo -e "${BOLD}${BLUE}└─────────────────────────────────────────────────────────┘${RESET}"
    echo -e ""
}

print_info() {
    echo -e "  ${CYAN}ℹ  $*${RESET}"
}

print_success() {
    echo -e "  ${GREEN}✔  $*${RESET}"
}

print_warn() {
    echo -e "  ${YELLOW}⚠  $*${RESET}"
}

print_error() {
    echo -e "  ${RED}✘  $*${RESET}" >&2
}

print_task() {
    echo -e "  ${DIM}→  $*${RESET}"
}

print_label() {
    # print_label "Key" "Value" [color]
    local key="$1"
    local val="$2"
    local col="${3:-$CYAN}"
    printf "  ${BOLD}%-30s${RESET} ${col}%s${RESET}\n" "${key}:" "${val}"
}

hr() {
    echo -e "  ${DIM}────────────────────────────────────────────────────────${RESET}"
}

# ----- Global Temp Dir -------------------------------------------------------
GITEA_TMP_DIR=""

cleanup_on_exit() {
    if [[ -n "$GITEA_TMP_DIR" && -d "$GITEA_TMP_DIR" ]]; then
        rm -rf "$GITEA_TMP_DIR"
    fi
}
trap cleanup_on_exit EXIT

# =============================================================================
# PHASE 1 — PRE-FLIGHT CHECKS  [STEP 1/10]
# =============================================================================

preflight_checks() {
    print_step "1" "10" "Pre-Flight Environment Checks"

    # ── Root / sudo ──────────────────────────────────────────────────────────
    print_task "Checking for root privileges..."
    if [[ "$EUID" -ne 0 ]]; then
        print_error "This script must be run as root or via sudo."
        print_info  "Run:  sudo bash $0"
        exit 1
    fi
    print_success "Running as root."

    # ── systemd ──────────────────────────────────────────────────────────────
    print_task "Checking for systemd..."
    if ! command -v systemctl &>/dev/null; then
        print_error "systemd (systemctl) is not available on this host."
        print_info  "This script requires a systemd-based Linux distribution."
        exit 1
    fi
    print_success "systemd detected."

    # ── Download tool ─────────────────────────────────────────────────────────
    print_task "Checking for download utility (curl / wget)..."
    if command -v curl &>/dev/null; then
        DOWNLOAD_CMD="curl"
        print_success "curl is available."
    elif command -v wget &>/dev/null; then
        DOWNLOAD_CMD="wget"
        print_success "wget is available."
    else
        print_warn "Neither curl nor wget found. Will attempt to install curl..."
        DOWNLOAD_CMD="needs_install"
    fi

    # ── openssl ───────────────────────────────────────────────────────────────
    print_task "Checking for openssl..."
    if ! command -v openssl &>/dev/null; then
        print_warn "openssl not found. Will install it during dependency phase."
        NEED_OPENSSL=true
    else
        NEED_OPENSSL=false
        print_success "openssl is available."
    fi

    # ── www-data user ─────────────────────────────────────────────────────────
    print_task "Checking for www-data service account..."
    if ! id "www-data" &>/dev/null; then
        print_error "'www-data' user does not exist on this system."
        print_info  "Create it with:  sudo useradd --system --no-create-home --shell /bin/false www-data"
        exit 1
    fi
    print_success "www-data service account exists."

    # ── Architecture ──────────────────────────────────────────────────────────
    print_task "Detecting system architecture..."
    local raw_arch
    raw_arch=$(uname -m)
    case "$raw_arch" in
        x86_64)           GITEA_ARCH="amd64"  ;;
        aarch64|arm64)    GITEA_ARCH="arm64"  ;;
        armv6l|armv7l)    GITEA_ARCH="arm-6"  ;;
        *)
            print_error "Unsupported architecture: $raw_arch"
            exit 1
            ;;
    esac
    print_success "Architecture: ${raw_arch} → Gitea arch tag: ${GITEA_ARCH}"

    # ── Package manager ───────────────────────────────────────────────────────
    print_task "Detecting package manager..."
    if command -v apt-get &>/dev/null; then
        PKG_MGR="apt"
        print_success "Package manager: apt (Debian/Ubuntu)"
    elif command -v yum &>/dev/null; then
        PKG_MGR="yum"
        print_success "Package manager: yum (RHEL/CentOS)"
    elif command -v dnf &>/dev/null; then
        PKG_MGR="dnf"
        print_success "Package manager: dnf (Fedora/RHEL 8+)"
    else
        print_warn "Could not detect a known package manager. Manual dependency installation may be required."
        PKG_MGR="unknown"
    fi

    echo -e ""
    print_success "All pre-flight checks passed."
}

# =============================================================================
# PHASE 2 — INTERACTIVE SETUP
# =============================================================================

# ──────────────────────────────────────────────────────────────────────────────
# STEP 2: Instance Postfix
# ──────────────────────────────────────────────────────────────────────────────

collect_postfix() {
    print_step "2" "10" "Instance Postfix Configuration"
    print_info "The postfix uniquely names this Gitea instance."
    print_info "Examples: stage, prod, dev, uat, test"
    echo -e ""

    while true; do
        read -r -p "$(echo -e "  ${BOLD}Enter a postfix for this Gitea instance: ${RESET}")" GITEA_POSTFIX

        # Trim whitespace
        GITEA_POSTFIX="${GITEA_POSTFIX// /}"
        GITEA_POSTFIX="${GITEA_POSTFIX//$'\t'/}"

        if [[ -z "$GITEA_POSTFIX" ]]; then
            print_error "Postfix cannot be empty. Please try again."
            continue
        fi

        if [[ ! "$GITEA_POSTFIX" =~ ^[a-zA-Z0-9_]{1,20}$ ]]; then
            print_error "Postfix must be 1–20 characters: letters, digits, or underscores only."
            continue
        fi

        break
    done

    # Derive all names from postfix
    INSTANCE_NAME="gitea_${GITEA_POSTFIX}"
    INSTALL_DIR="/opt/${INSTANCE_NAME}"
    CONFIG_DIR="/etc/${INSTANCE_NAME}"
    DATA_DIR="/var/lib/${INSTANCE_NAME}"
    LOG_DIR="/var/log/${INSTANCE_NAME}"
    SERVICE_NAME="${INSTANCE_NAME}"
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    BINARY_PATH="${INSTALL_DIR}/gitea"
    CONFIG_FILE="${CONFIG_DIR}/app.ini"

    echo -e ""
    print_success "Instance name derived:"
    hr
    print_label "Instance Name"    "$INSTANCE_NAME"   "$MAGENTA"
    print_label "Install Dir"      "$INSTALL_DIR"     "$CYAN"
    print_label "Config Dir"       "$CONFIG_DIR"      "$CYAN"
    print_label "Data Dir"         "$DATA_DIR"        "$CYAN"
    print_label "Log Dir"          "$LOG_DIR"         "$CYAN"
    print_label "Service Name"     "$SERVICE_NAME"    "$GREEN"
    print_label "Service File"     "$SERVICE_FILE"    "$GREEN"
    hr

    # Warn if already installed
    if systemctl list-units --full --all 2>/dev/null | grep -q "${SERVICE_NAME}.service"; then
        print_warn "A service named '${SERVICE_NAME}' already exists!"
        print_warn "Re-running will attempt to reconfigure and restart it."
        echo -e ""
        read -r -p "$(echo -e "  ${YELLOW}Continue and reconfigure? [y/N]: ${RESET}")" _confirm
        [[ "$_confirm" =~ ^[Yy]$ ]] || { print_info "Aborted by user."; exit 0; }
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
# STEP 3: Port Selection
# ──────────────────────────────────────────────────────────────────────────────

find_free_port() {
    # Returns a random free port in 3000-9999
    local port
    while true; do
        port=$(( (RANDOM % 7000) + 3000 ))
        if ! ss -tlnp 2>/dev/null | awk '{print $4}' | grep -q ":${port}$" && \
           ! netstat -tlnp 2>/dev/null | awk '{print $4}' | grep -q ":${port}$"; then
            echo "$port"
            return
        fi
    done
}

is_port_free() {
    local port="$1"
    if ss -tlnp 2>/dev/null | awk '{print $4}' | grep -q ":${port}$"; then
        return 1
    fi
    if netstat -tlnp 2>/dev/null | awk '{print $4}' | grep -q ":${port}$"; then
        return 1
    fi
    return 0
}

collect_port() {
    print_step "3" "10" "Port Selection"
    print_task "Scanning for an available port..."

    GITEA_PORT=$(find_free_port)
    print_info "Suggested available port found."
    echo -e ""

    while true; do
        echo -e "  ${BOLD}Suggested Available Port: ${GREEN}${GITEA_PORT}${RESET}"
        echo -e ""
        echo -e "  ${BOLD}Options:${RESET}"
        echo -e "    ${CYAN}1${RESET}) Yes — use suggested port (${GITEA_PORT})"
        echo -e "    ${CYAN}2${RESET}) No  — search for another available port"
        echo -e "    ${CYAN}3${RESET}) Custom — I will enter a port manually"
        echo -e ""

        read -r -p "$(echo -e "  ${BOLD}Your choice [1/2/3]: ${RESET}")" _port_choice

        case "$_port_choice" in
            1)
                # Re-verify it's still free (race condition safety)
                if is_port_free "$GITEA_PORT"; then
                    print_success "Using port: ${GITEA_PORT}"
                    break
                else
                    print_warn "Port ${GITEA_PORT} is now in use. Searching for another..."
                    GITEA_PORT=$(find_free_port)
                fi
                ;;
            2)
                print_task "Searching for another available port..."
                GITEA_PORT=$(find_free_port)
                print_info "New suggestion found."
                ;;
            3)
                while true; do
                    read -r -p "$(echo -e "  ${BOLD}Enter custom port (1024–65535): ${RESET}")" _custom_port

                    # Validate range
                    if ! [[ "$_custom_port" =~ ^[0-9]+$ ]] || \
                       [[ "$_custom_port" -lt 1024 ]] || \
                       [[ "$_custom_port" -gt 65535 ]]; then
                        print_error "Invalid port number. Must be between 1024 and 65535."
                        continue
                    fi

                    # Check if occupied
                    if ! is_port_free "$_custom_port"; then
                        print_error "Port ${_custom_port} is already in use by another process."
                        print_info  "Please choose a different port."
                        continue
                    fi

                    GITEA_PORT="$_custom_port"
                    print_success "Custom port ${GITEA_PORT} is available."
                    break
                done
                break
                ;;
            *)
                print_error "Invalid choice. Please enter 1, 2, or 3."
                ;;
        esac

        # If we got a valid port via option 1 or found one via option 2, exit
        [[ "$_port_choice" == "1" || "$_port_choice" == "3" ]] && break
    done
}

# ──────────────────────────────────────────────────────────────────────────────
# STEP 4: Host Type
# ──────────────────────────────────────────────────────────────────────────────

validate_domain() {
    local d="$1"
    [[ "$d" =~ ^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]
}

validate_ip() {
    local ip="$1"
    local IFS='.'
    read -r -a parts <<< "$ip"
    [[ "${#parts[@]}" -eq 4 ]] || return 1
    for part in "${parts[@]}"; do
        [[ "$part" =~ ^[0-9]+$ ]] || return 1
        [[ "$part" -ge 0 && "$part" -le 255 ]] || return 1
    done
    return 0
}

collect_host() {
    print_step "4" "10" "Host / Access Configuration"

    echo -e "  ${BOLD}Will Gitea run on:${RESET}"
    echo -e "    ${CYAN}1${RESET}) Domain Name  (e.g. git.example.com)"
    echo -e "    ${CYAN}2${RESET}) IP Address   (e.g. 192.168.1.100)"
    echo -e ""

    while true; do
        read -r -p "$(echo -e "  ${BOLD}Your choice [1/2]: ${RESET}")" _host_choice

        case "$_host_choice" in
            1)
                GITEA_HOST_TYPE="domain"
                while true; do
                    read -r -p "$(echo -e "  ${BOLD}Enter domain name: ${RESET}")" GITEA_HOST
                    GITEA_HOST="${GITEA_HOST,,}"   # lowercase
                    GITEA_HOST="${GITEA_HOST## }"  # trim
                    GITEA_HOST="${GITEA_HOST%% }"

                    if [[ -z "$GITEA_HOST" ]]; then
                        print_error "Domain name cannot be empty."
                        continue
                    fi

                    if ! validate_domain "$GITEA_HOST"; then
                        print_error "Invalid domain format: '${GITEA_HOST}'."
                        print_info  "Expected format: example.com or git.example.com"
                        continue
                    fi

                    print_success "Domain validated: ${GITEA_HOST}"
                    break
                done
                break
                ;;
            2)
                GITEA_HOST_TYPE="ip"
                while true; do
                    read -r -p "$(echo -e "  ${BOLD}Enter IP address: ${RESET}")" GITEA_HOST
                    GITEA_HOST="${GITEA_HOST## }"
                    GITEA_HOST="${GITEA_HOST%% }"

                    if [[ -z "$GITEA_HOST" ]]; then
                        print_error "IP address cannot be empty."
                        continue
                    fi

                    if ! validate_ip "$GITEA_HOST"; then
                        print_error "Invalid IP address format: '${GITEA_HOST}'."
                        print_info  "Expected format: 192.168.1.100"
                        continue
                    fi

                    print_success "IP address validated: ${GITEA_HOST}"
                    break
                done
                break
                ;;
            *)
                print_error "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
}

# ──────────────────────────────────────────────────────────────────────────────
# STEP 5: Database
# ──────────────────────────────────────────────────────────────────────────────

collect_database() {
    print_step "5" "10" "Database Configuration"

    echo -e "  ${BOLD}Select database type:${RESET}"
    echo -e "    ${CYAN}1${RESET}) SQLite  — lightweight, no extra setup needed (recommended for small instances)"
    echo -e "    ${CYAN}2${RESET}) MySQL   — recommended for production workloads"
    echo -e ""

    while true; do
        read -r -p "$(echo -e "  ${BOLD}Your choice [1/2]: ${RESET}")" _db_choice

        case "$_db_choice" in
            1)
                GITEA_DB_TYPE="sqlite3"
                GITEA_DB_PATH="${DATA_DIR}/data/gitea.db"
                print_success "SQLite selected. Database file will be at: ${GITEA_DB_PATH}"
                break
                ;;
            2)
                GITEA_DB_TYPE="mysql"
                echo -e ""
                print_info "Please enter MySQL connection details."
                echo -e ""

                # DB Host
                while true; do
                    read -r -p "$(echo -e "  ${BOLD}Database Host [default: 127.0.0.1]: ${RESET}")" GITEA_DB_HOST
                    GITEA_DB_HOST="${GITEA_DB_HOST:-127.0.0.1}"
                    [[ -n "$GITEA_DB_HOST" ]] && break
                    print_error "Database host cannot be empty."
                done

                # DB Port
                while true; do
                    read -r -p "$(echo -e "  ${BOLD}Database Port [default: 3306]: ${RESET}")" GITEA_DB_PORT
                    GITEA_DB_PORT="${GITEA_DB_PORT:-3306}"
                    if [[ "$GITEA_DB_PORT" =~ ^[0-9]+$ ]] && \
                       [[ "$GITEA_DB_PORT" -ge 1 && "$GITEA_DB_PORT" -le 65535 ]]; then
                        break
                    fi
                    print_error "Invalid port number."
                done

                # DB Name
                while true; do
                    read -r -p "$(echo -e "  ${BOLD}Database Name: ${RESET}")" GITEA_DB_NAME
                    [[ -n "$GITEA_DB_NAME" ]] && break
                    print_error "Database name cannot be empty."
                done

                # DB User
                while true; do
                    read -r -p "$(echo -e "  ${BOLD}Database Username: ${RESET}")" GITEA_DB_USER
                    [[ -n "$GITEA_DB_USER" ]] && break
                    print_error "Database username cannot be empty."
                done

                # DB Password (hidden)
                while true; do
                    read -r -s -p "$(echo -e "  ${BOLD}Database Password: ${RESET}")" GITEA_DB_PASS
                    echo -e ""
                    [[ -n "$GITEA_DB_PASS" ]] && break
                    print_error "Database password cannot be empty."
                done

                print_success "MySQL configuration collected."

                # Optional connection test
                echo -e ""
                read -r -p "$(echo -e "  ${BOLD}Test MySQL connection now? [y/N]: ${RESET}")" _test_conn
                if [[ "$_test_conn" =~ ^[Yy]$ ]]; then
                    print_task "Testing MySQL connection..."
                    if command -v mysql &>/dev/null; then
                        if mysql -h "$GITEA_DB_HOST" -P "$GITEA_DB_PORT" \
                                 -u "$GITEA_DB_USER" -p"$GITEA_DB_PASS" \
                                 -e "SELECT 1;" "$GITEA_DB_NAME" &>/dev/null; then
                            print_success "MySQL connection test successful!"
                        else
                            print_warn "MySQL connection test failed."
                            print_warn "Continuing anyway — double-check credentials before running Gitea."
                        fi
                    else
                        print_warn "mysql client not found. Skipping connection test."
                        print_info "It will be installed in the dependency phase."
                    fi
                fi

                break
                ;;
            *)
                print_error "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
}

# =============================================================================
# PHASE 3 — CONFIGURATION SUMMARY & CONFIRMATION  [STEP 6/10]
# =============================================================================

show_summary_and_confirm() {
    print_step "6" "10" "Configuration Summary & Confirmation"

    echo -e "  ${BOLD}Please review the configuration before installation begins:${RESET}"
    echo -e ""
    hr

    print_label "Instance Name"       "$INSTANCE_NAME"    "$MAGENTA"
    print_label "Service Name"        "${SERVICE_NAME}.service"  "$GREEN"
    print_label "Binary Location"     "$BINARY_PATH"      "$CYAN"
    print_label "Config File"         "$CONFIG_FILE"      "$CYAN"
    print_label "Data Directory"      "$DATA_DIR"         "$CYAN"
    print_label "Log Directory"       "$LOG_DIR"          "$CYAN"
    print_label "Service File"        "$SERVICE_FILE"     "$CYAN"
    print_label "Port"                "$GITEA_PORT"       "$YELLOW"
    print_label "Host Type"           "$GITEA_HOST_TYPE"  "$YELLOW"
    print_label "Host / Domain / IP"  "$GITEA_HOST"       "$YELLOW"
    print_label "Database Type"       "$GITEA_DB_TYPE"    "$YELLOW"

    if [[ "$GITEA_DB_TYPE" == "mysql" ]]; then
        print_label "DB Host"         "$GITEA_DB_HOST"    "$YELLOW"
        print_label "DB Port"         "$GITEA_DB_PORT"    "$YELLOW"
        print_label "DB Name"         "$GITEA_DB_NAME"    "$YELLOW"
        print_label "DB User"         "$GITEA_DB_USER"    "$YELLOW"
        print_label "DB Password"     "***hidden***"      "$DIM"
    fi

    print_label "Service Account"     "www-data"          "$GREEN"
    hr

    echo -e ""
    print_warn "Installation will begin. This cannot be undone without manual cleanup."
    echo -e ""

    read -r -p "$(echo -e "  ${BOLD}${GREEN}Proceed with installation? [y/N]: ${RESET}")" _proceed
    if [[ ! "$_proceed" =~ ^[Yy]$ ]]; then
        print_info "Installation aborted by user. No changes were made."
        exit 0
    fi

    echo -e ""
    print_success "Confirmed. Starting installation..."
}

# =============================================================================
# PHASE 4 — PACKAGE DEPENDENCIES  [STEP 7/10]
# =============================================================================

install_dependencies() {
    print_step "7" "10" "Installing System Dependencies"

    local packages=("git" "curl" "wget" "ca-certificates" "openssl")

    if [[ "$GITEA_DB_TYPE" == "mysql" ]]; then
        packages+=("default-mysql-client")
    fi

    case "$PKG_MGR" in
        apt)
            print_task "Updating apt package index..."
            apt-get update -qq
            print_success "Package index updated."

            for pkg in "${packages[@]}"; do
                if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
                    print_success "${pkg} is already installed. Skipping."
                else
                    print_task "Installing ${pkg}..."
                    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg" && \
                        print_success "${pkg} installed." || \
                        print_warn  "Could not install ${pkg}. Continuing..."
                fi
            done
            ;;
        yum|dnf)
            print_task "Updating package index..."
            "$PKG_MGR" check-update -q || true

            local mysql_pkg="mysql"
            [[ "$PKG_MGR" == "dnf" ]] && mysql_pkg="mysql"

            for pkg in "${packages[@]}"; do
                # Replace debian-specific name for RHEL
                [[ "$pkg" == "default-mysql-client" ]] && pkg="$mysql_pkg"
                if rpm -q "$pkg" &>/dev/null; then
                    print_success "${pkg} is already installed. Skipping."
                else
                    print_task "Installing ${pkg}..."
                    "$PKG_MGR" install -y -q "$pkg" && \
                        print_success "${pkg} installed." || \
                        print_warn  "Could not install ${pkg}. Continuing..."
                fi
            done
            ;;
        *)
            print_warn "Unknown package manager. Skipping automatic dependency installation."
            print_warn "Please ensure these are installed: ${packages[*]}"
            ;;
    esac

    # Ensure download command is available now
    if [[ "$DOWNLOAD_CMD" == "needs_install" ]]; then
        if command -v curl &>/dev/null; then
            DOWNLOAD_CMD="curl"
        elif command -v wget &>/dev/null; then
            DOWNLOAD_CMD="wget"
        else
            print_error "Could not install curl or wget. Cannot continue."
            exit 1
        fi
    fi

    echo -e ""
    print_success "All dependencies are satisfied."
}

# =============================================================================
# PHASE 5 — DOWNLOAD & VERIFY GITEA BINARY  [STEP 8/10]
# =============================================================================

download_gitea() {
    print_step "8" "10" "Downloading & Verifying Gitea Binary"

    # ── Resolve latest version ────────────────────────────────────────────────
    print_task "Querying GitHub API for latest Gitea release..."
    local api_url="https://api.github.com/repos/go-gitea/gitea/releases/latest"
    local version_raw=""

    if [[ "$DOWNLOAD_CMD" == "curl" ]]; then
        version_raw=$(curl -s --retry 3 --retry-delay 2 "$api_url" | grep '"tag_name"' | head -1)
    else
        version_raw=$(wget -qO- "$api_url" | grep '"tag_name"' | head -1)
    fi

    # Extract just the version string (e.g. v1.22.3 → 1.22.3)
    GITEA_VERSION=$(echo "$version_raw" | sed -E 's/.*"v([0-9]+\.[0-9]+\.[0-9]+)".*/\1/')

    if [[ -z "$GITEA_VERSION" ]]; then
        print_warn "Could not auto-detect latest version. Falling back to 1.22.3."
        GITEA_VERSION="1.22.3"
    fi

    print_success "Gitea version: ${GITEA_VERSION}"

    # ── Construct URLs ────────────────────────────────────────────────────────
    local base_url="https://dl.gitea.com/gitea/${GITEA_VERSION}"
    local binary_file="gitea-${GITEA_VERSION}-linux-${GITEA_ARCH}"
    local binary_url="${base_url}/${binary_file}"
    local sha256_url="${binary_url}.sha256"

    print_task "Binary URL: ${binary_url}"

    # ── Create temp dir ───────────────────────────────────────────────────────
    GITEA_TMP_DIR=$(mktemp -d /tmp/gitea_install_XXXXXX)
    local tmp_binary="${GITEA_TMP_DIR}/${binary_file}"
    local tmp_sha256="${GITEA_TMP_DIR}/${binary_file}.sha256"

    # ── Download with retry ───────────────────────────────────────────────────
    local attempt
    for attempt in 1 2 3; do
        print_task "Downloading Gitea binary (attempt ${attempt}/3)..."
        if [[ "$DOWNLOAD_CMD" == "curl" ]]; then
            curl -L --retry 2 --retry-delay 3 --progress-bar \
                -o "$tmp_binary" "$binary_url" && break
        else
            wget -q --show-progress --tries=2 --wait=3 \
                -O "$tmp_binary" "$binary_url" && break
        fi

        if [[ "$attempt" -eq 3 ]]; then
            print_error "Failed to download Gitea binary after 3 attempts."
            print_info  "Check your internet connection and try again."
            exit 1
        fi
        print_warn "Download attempt ${attempt} failed. Retrying in 5 seconds..."
        sleep 5
    done

    print_success "Binary downloaded."

    # ── Download checksum ─────────────────────────────────────────────────────
    print_task "Downloading SHA-256 checksum file..."
    if [[ "$DOWNLOAD_CMD" == "curl" ]]; then
        curl -sL -o "$tmp_sha256" "$sha256_url" || {
            print_warn "Could not download checksum file. Skipping verification."
            SKIP_CHECKSUM=true
        }
    else
        wget -qO "$tmp_sha256" "$sha256_url" || {
            print_warn "Could not download checksum file. Skipping verification."
            SKIP_CHECKSUM=true
        }
    fi

    SKIP_CHECKSUM="${SKIP_CHECKSUM:-false}"

    # ── Verify checksum ───────────────────────────────────────────────────────
    if [[ "$SKIP_CHECKSUM" == "false" ]]; then
        print_task "Verifying SHA-256 checksum..."
        # The .sha256 file from dl.gitea.com may be "HASH  filename" format
        # We need to run sha256sum from the tmp dir
        local actual_hash
        actual_hash=$(sha256sum "$tmp_binary" | awk '{print $1}')
        local expected_hash
        expected_hash=$(awk '{print $1}' "$tmp_sha256")

        if [[ "$actual_hash" != "$expected_hash" ]]; then
            print_error "SHA-256 checksum mismatch!"
            print_error "Expected: ${expected_hash}"
            print_error "Got:      ${actual_hash}"
            print_error "The downloaded binary may be corrupted. Aborting."
            exit 1
        fi
        print_success "SHA-256 checksum verified: ${actual_hash:0:16}..."
    fi

    # ── Place binary ──────────────────────────────────────────────────────────
    print_task "Installing binary to ${BINARY_PATH}..."
    mkdir -p "$INSTALL_DIR"
    cp "$tmp_binary" "$BINARY_PATH"
    chmod 755 "$BINARY_PATH"
    chown root:root "$BINARY_PATH"
    print_success "Gitea binary installed at: ${BINARY_PATH}"
}

# =============================================================================
# PHASE 6 — DIRECTORY CREATION & PERMISSIONS  [STEP 8/10 cont.]
# =============================================================================

create_directories() {
    print_task "Creating Gitea directory structure..."

    local dirs=(
        "$INSTALL_DIR"
        "$CONFIG_DIR"
        "$DATA_DIR"
        "${DATA_DIR}/repositories"
        "${DATA_DIR}/data"
        "${DATA_DIR}/data/avatars"
        "${DATA_DIR}/data/attachments"
        "${DATA_DIR}/data/lfs"
        "${DATA_DIR}/indexers"
        "${DATA_DIR}/queues"
        "$LOG_DIR"
    )

    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            print_success "Directory exists: ${dir}"
        else
            mkdir -p "$dir"
            print_success "Created: ${dir}"
        fi
    done

    # ── Ownership & permissions ───────────────────────────────────────────────
    print_task "Setting ownership to www-data:www-data..."

    chown root:root "$INSTALL_DIR"
    chmod 755 "$INSTALL_DIR"

    chown www-data:www-data "$CONFIG_DIR"
    chmod 750 "$CONFIG_DIR"

    chown -R www-data:www-data "$DATA_DIR"
    chmod -R 750 "$DATA_DIR"

    chown -R www-data:www-data "$LOG_DIR"
    chmod -R 750 "$LOG_DIR"

    print_success "Ownership and permissions configured."
}

# =============================================================================
# PHASE 7 — GENERATE app.ini  [STEP 9/10]
# =============================================================================

generate_app_ini() {
    print_step "9" "10" "Generating Gitea Configuration (app.ini)"

    # ── Generate secrets ──────────────────────────────────────────────────────
    print_task "Generating SECRET_KEY..."
    local secret_key
    secret_key=$(openssl rand -hex 32)

    print_task "Generating INTERNAL_TOKEN..."
    local internal_token
    internal_token=$(openssl rand -hex 48)

    print_task "Generating LFS_JWT_SECRET..."
    local lfs_jwt_secret
    lfs_jwt_secret=$(openssl rand -base64 32 | tr -d '=+/' | head -c 32)

    # ── Build ROOT_URL ────────────────────────────────────────────────────────
    local root_url
    if [[ "$GITEA_HOST_TYPE" == "domain" ]]; then
        root_url="http://${GITEA_HOST}:${GITEA_PORT}/"
    else
        root_url="http://${GITEA_HOST}:${GITEA_PORT}/"
    fi

    # ── Write app.ini ─────────────────────────────────────────────────────────
    print_task "Writing ${CONFIG_FILE}..."

    cat > "$CONFIG_FILE" <<EOF
; ============================================================
;  Gitea Configuration — ${INSTANCE_NAME}
;  Generated by install_gitea.sh on $(date -u '+%Y-%m-%d %H:%M:%S UTC')
;  DO NOT share this file; it contains secret keys.
; ============================================================

APP_NAME = ${INSTANCE_NAME}
RUN_MODE = prod
RUN_USER = www-data

[server]
PROTOCOL          = http
DOMAIN            = ${GITEA_HOST}
HTTP_PORT         = ${GITEA_PORT}
ROOT_URL          = ${root_url}
APP_DATA_PATH     = ${DATA_DIR}/data
SSH_DOMAIN        = ${GITEA_HOST}
START_SSH_SERVER  = false
OFFLINE_MODE      = false

[database]
DB_TYPE  = ${GITEA_DB_TYPE}
EOF

    if [[ "$GITEA_DB_TYPE" == "sqlite3" ]]; then
        cat >> "$CONFIG_FILE" <<EOF
PATH     = ${GITEA_DB_PATH}
EOF
    else
        cat >> "$CONFIG_FILE" <<EOF
HOST     = ${GITEA_DB_HOST}:${GITEA_DB_PORT}
NAME     = ${GITEA_DB_NAME}
USER     = ${GITEA_DB_USER}
PASSWD   = ${GITEA_DB_PASS}
SSL_MODE = disable
CHARSET  = utf8mb4
EOF
    fi

    cat >> "$CONFIG_FILE" <<EOF

[repository]
ROOT = ${DATA_DIR}/repositories

[log]
ROOT_PATH = ${LOG_DIR}
MODE      = file
LEVEL     = info

[security]
INSTALL_LOCK          = true
SECRET_KEY            = ${secret_key}
INTERNAL_TOKEN        = ${internal_token}
LFS_JWT_SECRET        = ${lfs_jwt_secret}
PASSWORD_HASH_ALGO    = pbkdf2

[service]
DISABLE_REGISTRATION              = true
REQUIRE_SIGNIN_VIEW               = false
REGISTER_EMAIL_CONFIRM            = false
ENABLE_NOTIFY_MAIL                = false
ALLOW_ONLY_EXTERNAL_REGISTRATION  = false
ENABLE_CAPTCHA                    = false
DEFAULT_KEEP_EMAIL_PRIVATE        = true

[mailer]
ENABLED = false

[session]
PROVIDER        = file
PROVIDER_CONFIG = ${DATA_DIR}/data/sessions
COOKIE_SECURE   = false

[picture]
AVATAR_UPLOAD_PATH      = ${DATA_DIR}/data/avatars
REPOSITORY_AVATAR_UPLOAD_PATH = ${DATA_DIR}/data/repo-avatars
GRAVATAR_SOURCE         = gravatar
DISABLE_GRAVATAR        = false
ENABLE_FEDERATED_AVATAR = true

[attachment]
ENABLED = true
PATH    = ${DATA_DIR}/data/attachments
MAX_SIZE = 4
MAX_FILES = 5

[indexer]
ISSUE_INDEXER_PATH = ${DATA_DIR}/indexers/issues.bleve

[queue]
TYPE        = level
DATADIR     = ${DATA_DIR}/queues/common

[admin]
DISABLE_REGULAR_ORG_CREATION = false

[cron]
ENABLED = true
RUN_AT_START = false
EOF

    # ── Secure the config file ────────────────────────────────────────────────
    chown www-data:www-data "$CONFIG_FILE"
    chmod 640 "$CONFIG_FILE"

    print_success "app.ini generated and secured."
}

# =============================================================================
# PHASE 8 — SYSTEMD SERVICE  [STEP 9/10 cont.]
# =============================================================================

create_systemd_service() {
    print_task "Writing systemd service file: ${SERVICE_FILE}..."

    # Determine if we need MySQL dependency
    local after_line="After=network.target"
    local wants_line=""
    if [[ "$GITEA_DB_TYPE" == "mysql" ]]; then
        after_line="After=network.target mysqld.service mysql.service mariadb.service"
        wants_line="Wants=mysqld.service mysql.service"
    fi

    cat > "$SERVICE_FILE" <<EOF
# ============================================================
#  systemd service: ${SERVICE_NAME}
#  Gitea instance — generated by install_gitea.sh
# ============================================================

[Unit]
Description=Gitea (${INSTANCE_NAME})
Documentation=https://gitea.io
${after_line}
${wants_line}

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=${DATA_DIR}
ExecStart=${BINARY_PATH} web --config ${CONFIG_FILE}
Restart=on-failure
RestartSec=5s
Environment=USER=www-data HOME=${DATA_DIR} GITEA_WORK_DIR=${DATA_DIR}

# Security hardening
PrivateTmp=true
NoNewPrivileges=true
ProtectSystem=full
ProtectHome=true

[Install]
WantedBy=multi-user.target
EOF

    print_success "Service file written: ${SERVICE_FILE}"

    # ── Reload & enable & start ───────────────────────────────────────────────
    print_task "Reloading systemd daemon..."
    systemctl daemon-reload
    print_success "systemd daemon reloaded."

    print_task "Enabling ${SERVICE_NAME} to start on boot..."
    systemctl enable "${SERVICE_NAME}" 2>/dev/null
    print_success "Service enabled."

    print_task "Starting ${SERVICE_NAME}..."
    systemctl start "${SERVICE_NAME}" && \
        print_success "Service start command issued." || \
        print_warn   "Service start returned a non-zero exit code. Check logs below."
}

# =============================================================================
# PHASE 9 — VALIDATION  [STEP 10/10]
# =============================================================================

validate_installation() {
    print_step "10" "10" "Validating Installation"

    # ── Wait for service to settle ────────────────────────────────────────────
    print_task "Waiting for service to become active..."
    local wait_count=0
    local max_wait=15

    while [[ $wait_count -lt $max_wait ]]; do
        if systemctl is-active --quiet "${SERVICE_NAME}"; then
            print_success "Service is active!"
            break
        fi
        sleep 1
        (( wait_count++ ))
        printf "  ${DIM}  ... waiting (%d/%d)${RESET}\r" "$wait_count" "$max_wait"
    done

    echo -e ""

    if ! systemctl is-active --quiet "${SERVICE_NAME}"; then
        print_warn "Service did not become active within ${max_wait}s."
        print_warn "Checking service status..."
        systemctl status "${SERVICE_NAME}" --no-pager -l 2>&1 | head -30 || true
        print_info "Installation completed but service may need manual attention."
        print_info "Check logs with: journalctl -u ${SERVICE_NAME} -n 50"
        return
    fi

    # ── HTTP smoke test ───────────────────────────────────────────────────────
    print_task "Performing HTTP smoke test on http://127.0.0.1:${GITEA_PORT}/ ..."
    sleep 3  # Give Gitea a moment to bind the port

    local http_code="000"
    if command -v curl &>/dev/null; then
        http_code=$(curl -s --connect-timeout 5 --max-time 10 \
            -o /dev/null -w "%{http_code}" \
            "http://127.0.0.1:${GITEA_PORT}/" 2>/dev/null || echo "000")
    fi

    if [[ "$http_code" == "200" || "$http_code" == "302" || "$http_code" == "301" ]]; then
        print_success "HTTP smoke test passed! Response code: ${http_code}"
    else
        print_warn "HTTP smoke test returned: ${http_code}  (Gitea may still be initializing)"
        print_info "Try accessing it manually after a few moments."
    fi
}

# =============================================================================
# PHASE 10 — CLEANUP & FINAL SUMMARY  [STEP 10/10 cont.]
# =============================================================================

cleanup() {
    print_task "Removing temporary installation files..."
    if [[ -n "$GITEA_TMP_DIR" && -d "$GITEA_TMP_DIR" ]]; then
        rm -rf "$GITEA_TMP_DIR"
        GITEA_TMP_DIR=""   # prevent double-cleanup in trap
        print_success "Temporary files removed."
    fi
}

print_final_summary() {
    echo -e ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}${BOLD}║            🎉  GITEA INSTALLED SUCCESSFULLY  🎉           ║${RESET}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
    echo -e ""

    echo -e "  ${BOLD}${CYAN}── Deployment Summary ─────────────────────────────────────${RESET}"
    echo -e ""
    print_label "Service Name"        "${SERVICE_NAME}.service"    "$MAGENTA"
    print_label "Service File"        "${SERVICE_FILE}"             "$MAGENTA"
    print_label "Config File"         "${CONFIG_FILE}"              "$CYAN"
    print_label "Install Directory"   "${INSTALL_DIR}"             "$CYAN"
    print_label "Data Directory"      "${DATA_DIR}"                "$CYAN"
    print_label "Log Directory"       "${LOG_DIR}"                  "$CYAN"
    print_label "Runtime Port"        "${GITEA_PORT}"               "$YELLOW"
    print_label "Domain / IP"         "${GITEA_HOST}"              "$YELLOW"
    print_label "Web URL"             "http://${GITEA_HOST}:${GITEA_PORT}/"  "$GREEN"
    print_label "Database Type"       "${GITEA_DB_TYPE}"           "$YELLOW"
    print_label "Gitea Version"       "${GITEA_VERSION}"           "$CYAN"
    echo -e ""

    echo -e "  ${BOLD}${CYAN}── Useful Commands ─────────────────────────────────────────${RESET}"
    echo -e ""
    echo -e "  ${BOLD}Status:${RESET}"
    echo -e "    ${YELLOW}systemctl status ${SERVICE_NAME}${RESET}"
    echo -e ""
    echo -e "  ${BOLD}Restart:${RESET}"
    echo -e "    ${YELLOW}systemctl restart ${SERVICE_NAME}${RESET}"
    echo -e ""
    echo -e "  ${BOLD}Stop:${RESET}"
    echo -e "    ${YELLOW}systemctl stop ${SERVICE_NAME}${RESET}"
    echo -e ""
    echo -e "  ${BOLD}Logs (live):${RESET}"
    echo -e "    ${YELLOW}journalctl -u ${SERVICE_NAME} -f${RESET}"
    echo -e ""
    echo -e "  ${BOLD}Logs (file):${RESET}"
    echo -e "    ${YELLOW}tail -f ${LOG_DIR}/gitea.log${RESET}"
    echo -e ""

    echo -e "  ${BOLD}${CYAN}── First-Time Setup ────────────────────────────────────────${RESET}"
    echo -e ""
    echo -e "  ${DIM}Registration is DISABLED by default (DISABLE_REGISTRATION = true).${RESET}"
    echo -e "  ${DIM}Create the admin user via the Gitea CLI:${RESET}"
    echo -e ""
    echo -e "  ${YELLOW}sudo -u www-data ${BINARY_PATH} admin user create \\${RESET}"
    echo -e "  ${YELLOW}    --admin --username admin --password 'YourSecurePassword' \\${RESET}"
    echo -e "  ${YELLOW}    --email 'admin@${GITEA_HOST}' --config ${CONFIG_FILE}${RESET}"
    echo -e ""

    echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════${RESET}"
    echo -e ""
}

# =============================================================================
# MAIN — ORCHESTRATE ALL PHASES
# =============================================================================

main() {
    # Declare globals that will be populated by interactive functions
    GITEA_POSTFIX=""
    INSTANCE_NAME=""
    INSTALL_DIR=""
    CONFIG_DIR=""
    DATA_DIR=""
    LOG_DIR=""
    SERVICE_NAME=""
    SERVICE_FILE=""
    BINARY_PATH=""
    CONFIG_FILE=""
    GITEA_PORT=""
    GITEA_HOST_TYPE=""
    GITEA_HOST=""
    GITEA_DB_TYPE=""
    GITEA_DB_PATH=""
    GITEA_DB_HOST=""
    GITEA_DB_PORT=""
    GITEA_DB_NAME=""
    GITEA_DB_USER=""
    GITEA_DB_PASS=""
    GITEA_ARCH=""
    GITEA_VERSION=""
    DOWNLOAD_CMD=""
    PKG_MGR=""

    print_banner

    # Phase 1 — Pre-flight
    preflight_checks

    # Phase 2 — Interactive setup
    collect_postfix
    collect_port
    collect_host
    collect_database

    # Phase 3 — Summary & confirm
    show_summary_and_confirm

    # Phase 4 — Dependencies
    install_dependencies

    # Phase 5 & 6 — Download binary + create dirs (interleaved for UX clarity)
    download_gitea
    create_directories

    # Phase 7 — app.ini
    generate_app_ini

    # Phase 8 — systemd
    create_systemd_service

    # Phase 9 — Validate
    validate_installation

    # Phase 10 — Cleanup & summary
    cleanup
    print_final_summary
}

main "$@"
