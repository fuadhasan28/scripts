#!/bin/bash

################################################################################
# Gitea Installation Script
# Supports multiple instances with interactive configuration
# Requirements: Linux (Ubuntu/Debian), MySQL/SQLite, www-data user
################################################################################

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Temp files cleanup list
TEMP_FILES=()

# Cleanup function
cleanup() {
    if [ ${#TEMP_FILES[@]} -gt 0 ]; then
        for file in "${TEMP_FILES[@]}"; do
            if [ -f "$file" ]; then
                rm -f "$file"
            fi
        done
    fi
}

trap cleanup EXIT

# Logging functions
log_header() {
    echo -e "\n${BOLD}${BLUE}=== $1 ===${NC}\n"
}

log_step() {
    echo -e "${CYAN}▶ $1${NC}"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

log_info() {
    echo -e "${BOLD}ℹ $1${NC}"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    log_step "Checking dependencies..."
    
    local missing_deps=()
    
    command -v git &> /dev/null || missing_deps+=("git")
    command -v curl &> /dev/null || missing_deps+=("curl")
    command -v wget &> /dev/null || missing_deps+=("wget")
    command -v ss &> /dev/null || missing_deps+=("iproute2")
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_warning "Installing missing dependencies: ${missing_deps[*]}"
        apt update -qq
        apt install -y -qq "${missing_deps[@]}"
    fi
    
    log_success "All dependencies are available"
}

# Check if www-data user exists
check_www_data_user() {
    log_step "Checking www-data user..."
    
    if ! id "www-data" &>/dev/null; then
        log_warning "www-data user not found, creating..."
        useradd --system --shell /bin/bash --create-home -d /var/www www-data
        log_success "www-data user created"
    else
        log_success "www-data user exists"
    fi
}

# Get postfix from user
get_postfix() {
    log_header "Gitea Instance Postfix"
    
    read -p "$(echo -e ${CYAN}Enter postfix for this Gitea instance${NC} (e.g., stage, prod): " -r postfix
    
    if [ -z "$postfix" ]; then
        log_error "Postfix cannot be empty"
        get_postfix
        return
    fi
    
    # Check if instance already exists
    if [ -d "/var/lib/gitea_${postfix}" ] || [ -f "/etc/gitea_${postfix}/app.ini" ]; then
        log_error "Gitea instance 'gitea_${postfix}' already exists"
        get_postfix
        return
    fi
    
    GITEA_POSTFIX="$postfix"
    INSTANCE_NAME="gitea_${postfix}"
    log_success "Using postfix: ${BOLD}${INSTANCE_NAME}${NC}"
}

# Find a random available port
find_available_port() {
    local port
    
    while true; do
        # Generate random port between 3000 and 9999
        port=$((RANDOM % 6999 + 3000))
        
        # Check if port is available
        if ! ss -tuln 2>/dev/null | grep -q ":$port "; then
            echo "$port"
            return
        fi
    done
}

# Validate port
validate_port() {
    local port=$1
    
    # Check if port is a valid number
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        log_error "Port must be a number"
        return 1
    fi
    
    # Check if port is in valid range
    if [ "$port" -lt 1024 ] || [ "$port" -gt 65535 ]; then
        log_error "Port must be between 1024 and 65535"
        return 1
    fi
    
    # Check if port is available
    if ss -tuln 2>/dev/null | grep -q ":$port "; then
        log_error "Port $port is already in use"
        return 1
    fi
    
    return 0
}

# Get port from user
get_port() {
    log_header "Port Configuration"
    
    while true; do
        local suggested_port
        suggested_port=$(find_available_port)
        
        log_info "Suggested available port: ${BOLD}${BLUE}${suggested_port}${NC}"
        
        echo ""
        echo -e "${CYAN}Choose an option:${NC}"
        echo -e "  ${BOLD}Y${NC}) Yes, use suggested port ${suggested_port}"
        echo -e "  ${BOLD}N${NC}) No, find another port"
        echo -e "  ${BOLD}C${NC}) Custom, enter port manually"
        echo ""
        
        read -p "$(echo -e ${CYAN}Enter choice${NC} [Y/N/C]: " -r port_choice
        port_choice=$(echo "$port_choice" | tr '[:upper:]' '[:lower:]')
        
        case "$port_choice" in
            y|yes)
                GITEA_PORT="$suggested_port"
                log_success "Using port: ${BOLD}${BLUE}${GITEA_PORT}${NC}"
                return 0
                ;;
            n|no)
                continue
                ;;
            c|custom)
                read -p "$(echo -e ${CYAN}Enter port number${NC}: " -r custom_port
                
                if validate_port "$custom_port"; then
                    GITEA_PORT="$custom_port"
                    log_success "Using port: ${BOLD}${BLUE}${GITEA_PORT}${NC}"
                    return 0
                else
                    log_error "Invalid port. Please try again."
                fi
                ;;
            *)
                log_error "Invalid choice. Please enter Y, N, or C."
                ;;
        esac
    done
}

# Get domain/IP from user
get_domain_ip() {
    log_header "Domain/IP Configuration"
    
    echo ""
    echo -e "${CYAN}How will you access this Gitea instance?${NC}"
    echo -e "  ${BOLD}D${NC}) Domain"
    echo -e "  ${BOLD}I${NC}) IP Address"
    echo ""
    
    read -p "$(echo -e ${CYAN}Enter choice${NC} [D/I]: " -r domain_ip_choice
    domain_ip_choice=$(echo "$domain_ip_choice" | tr '[:upper:]' '[:lower:]')
    
    case "$domain_ip_choice" in
        d|domain)
            read -p "$(echo -e ${CYAN}Enter domain name${NC} (e.g., git.example.com): " -r domain
            
            if [ -z "$domain" ]; then
                log_error "Domain cannot be empty"
                get_domain_ip
                return
            fi
            
            GITEA_DOMAIN="$domain"
            GITEA_ACCESS_TYPE="domain"
            log_success "Using domain: ${BOLD}${BLUE}${GITEA_DOMAIN}${NC}"
            ;;
        i|ip)
            read -p "$(echo -e ${CYAN}Enter IP address${NC} (leave empty for localhost): " -r ip_addr
            
            if [ -z "$ip_addr" ]; then
                ip_addr="localhost"
            fi
            
            GITEA_DOMAIN="$ip_addr"
            GITEA_ACCESS_TYPE="ip"
            log_success "Using IP: ${BOLD}${BLUE}${GITEA_DOMAIN}${NC}"
            ;;
        *)
            log_error "Invalid choice. Please enter D or I."
            get_domain_ip
            ;;
    esac
}

# Get database configuration
get_database_config() {
    log_header "Database Configuration"
    
    echo ""
    echo -e "${CYAN}Choose database type:${NC}"
    echo -e "  ${BOLD}S${NC}) SQLite (simple, no setup required)"
    echo -e "  ${BOLD}M${NC}) MySQL (recommended for production)"
    echo ""
    
    read -p "$(echo -e ${CYAN}Enter choice${NC} [S/M]: " -r db_choice
    db_choice=$(echo "$db_choice" | tr '[:upper:]' '[:lower:]')
    
    case "$db_choice" in
        s|sqlite)
            DB_TYPE="sqlite3"
            DB_PATH="/var/lib/${INSTANCE_NAME}/data/gitea.db"
            log_success "Using database: ${BOLD}${BLUE}SQLite3${NC}"
            log_info "Database will be stored at: ${BOLD}${DB_PATH}${NC}"
            ;;
        m|mysql)
            log_info "Please provide MySQL database credentials"
            
            read -p "$(echo -e ${CYAN}MySQL Host${NC} (default: 127.0.0.1): " -r db_host
            db_host="${db_host:-127.0.0.1}"
            
            read -p "$(echo -e ${CYAN}MySQL Port${NC} (default: 3306): " -r db_port
            db_port="${db_port:-3306}"
            
            read -p "$(echo -e ${CYAN}Database Name${NC}: " -r db_name
            if [ -z "$db_name" ]; then
                log_error "Database name cannot be empty"
                get_database_config
                return
            fi
            
            read -p "$(echo -e ${CYAN}Database User${NC}: " -r db_user
            if [ -z "$db_user" ]; then
                log_error "Database user cannot be empty"
                get_database_config
                return
            fi
            
            read -sp "$(echo -e ${CYAN}Database Password${NC}: " -r db_pass
            echo ""
            
            if [ -z "$db_pass" ]; then
                log_warning "Database password is empty"
            fi
            
            DB_TYPE="mysql"
            DB_HOST="$db_host"
            DB_PORT="$db_port"
            DB_NAME="$db_name"
            DB_USER="$db_user"
            DB_PASS="$db_pass"
            
            log_success "MySQL configuration saved"
            log_info "Database: ${BOLD}${DB_NAME}${NC} | User: ${BOLD}${DB_USER}${NC} | Host: ${BOLD}${DB_HOST}:${DB_PORT}${NC}"
            ;;
        *)
            log_error "Invalid choice. Please enter S or M."
            get_database_config
            ;;
    esac
}

# Download Gitea binary
download_gitea() {
    log_header "Downloading Gitea"
    
    log_step "Fetching latest Gitea release information..."
    
    local latest_version
    latest_version=$(curl -s https://api.github.com/repos/go-gitea/gitea/releases/latest | grep -oP '"tag_name": "\K[^"]*' | head -1)
    
    if [ -z "$latest_version" ]; then
        log_error "Failed to fetch latest Gitea version"
        return 1
    fi
    
    log_info "Latest Gitea version: ${BOLD}${BLUE}${latest_version}${NC}"
    
    # Determine architecture
    local arch
    arch=$(uname -m)
    if [ "$arch" = "x86_64" ]; then
        arch="amd64"
    elif [ "$arch" = "aarch64" ]; then
        arch="arm64"
    fi
    
    local download_url="https://github.com/go-gitea/gitea/releases/download/${latest_version}/gitea-${latest_version}-linux-${arch}"
    local temp_binary="/tmp/gitea-${latest_version}-linux-${arch}"
    
    TEMP_FILES+=("$temp_binary")
    
    log_step "Downloading Gitea binary (${arch})..."
    
    if ! wget -q --show-progress "$download_url" -O "$temp_binary" 2>/dev/null; then
        log_error "Failed to download Gitea from $download_url"
        return 1
    fi
    
    chmod +x "$temp_binary"
    
    # Check if gitea already exists
    if [ -f "/usr/local/bin/gitea" ]; then
        log_warning "Gitea binary already exists at /usr/local/bin/gitea"
        log_step "Backing up existing binary to /usr/local/bin/gitea.backup"
        cp /usr/local/bin/gitea /usr/local/bin/gitea.backup
    fi
    
    cp "$temp_binary" /usr/local/bin/gitea
    chmod +x /usr/local/bin/gitea
    
    log_success "Gitea binary installed at /usr/local/bin/gitea"
    
    # Verify installation
    /usr/local/bin/gitea --version
}

# Create directories and set permissions
create_directories() {
    log_header "Creating Directories and Setting Permissions"
    
    local dirs=(
        "/var/lib/${INSTANCE_NAME}"
        "/var/lib/${INSTANCE_NAME}/custom"
        "/var/lib/${INSTANCE_NAME}/data"
        "/var/lib/${INSTANCE_NAME}/log"
        "/etc/gitea"
        "/var/run/${INSTANCE_NAME}"
    )
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            log_step "Creating directory: $dir"
            mkdir -p "$dir"
        fi
    done
    
    log_step "Setting ownership to www-data..."
    chown -R www-data:www-data "/var/lib/${INSTANCE_NAME}"
    chown -R www-data:www-data "/var/run/${INSTANCE_NAME}"
    
    log_step "Setting permissions..."
    chmod 750 "/etc/gitea" "/var/lib/${INSTANCE_NAME}" "/var/run/${INSTANCE_NAME}"
    chmod 700 "/var/lib/${INSTANCE_NAME}/data"
    
    log_success "Directories created and permissions set"
}

# Create configuration file
create_config() {
    log_header "Creating Gitea Configuration"
    
    local config_file="/etc/gitea/app_${GITEA_POSTFIX}.ini"
    local protocol="http"
    
    if [ "$GITEA_ACCESS_TYPE" = "domain" ]; then
        protocol="https"
    fi
    
    log_step "Creating configuration file: $config_file"
    
    cat > "$config_file" << EOF
APP_NAME = Gitea ${GITEA_POSTFIX}
RUN_MODE = prod

[server]
PROTOCOL = ${protocol}
DOMAIN = ${GITEA_DOMAIN}
ROOT_URL = ${protocol}://${GITEA_DOMAIN}/
HTTP_ADDR = 127.0.0.1
HTTP_PORT = ${GITEA_PORT}
UNIX_SOCKET_PERMISSION = 666
LOG_MODE = console
TRUSTED_PROXIES = 127.0.0.1/8,::1/128

[database]
EOF

    if [ "$DB_TYPE" = "sqlite3" ]; then
        cat >> "$config_file" << EOF
DB_TYPE = sqlite3
PATH = ${DB_PATH}
EOF
    else
        cat >> "$config_file" << EOF
DB_TYPE = mysql
HOST = ${DB_HOST}:${DB_PORT}
NAME = ${DB_NAME}
USER = ${DB_USER}
PASSWD = ${DB_PASS}
SSL_MODE = false
CHARSET = utf8mb4
LOG_SQL = false
EOF
    fi

    cat >> "$config_file" << EOF

[cache]
ADAPTER = memory

[session]
PROVIDER = memory

[picture]
AVATAR_UPLOAD_PATH = data/avatars
REPOSITORY_AVATAR_UPLOAD_PATH = data/repo-avatars

[attachment]
STORAGE_TYPE = local
SERVE_DIRECT = false
PATH = /var/lib/${INSTANCE_NAME}/data/attachments

[log]
MODE = console
LEVEL = info
ROOT_PATH = /var/lib/${INSTANCE_NAME}/log

[security]
INSTALL_LOCK = false
SECRET_KEY = $(openssl rand -hex 16)
EOF

    chown www-data:www-data "$config_file"
    chmod 600 "$config_file"
    
    CONFIG_FILE="$config_file"
    log_success "Configuration file created"
}

# Create systemd service
create_systemd_service() {
    log_header "Creating Systemd Service"
    
    local service_file="/etc/systemd/system/${INSTANCE_NAME}.service"
    
    log_step "Creating service file: $service_file"
    
    cat > "$service_file" << EOF
[Unit]
Description=Gitea ${GITEA_POSTFIX}
After=syslog.target network-online.target remote-fs.target nss-lookup.target mysql.service
Wants=network-online.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/var/lib/${INSTANCE_NAME}
ExecStart=/usr/local/bin/gitea web --config ${CONFIG_FILE}
Restart=always
RestartSec=10
Environment=USER=www-data HOME=/var/lib/${INSTANCE_NAME} GITEA_WORK_DIR=/var/lib/${INSTANCE_NAME}

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "$service_file"
    
    SERVICE_FILE="$service_file"
    log_success "Systemd service file created"
}

# Initialize Gitea
initialize_gitea() {
    log_header "Initializing Gitea"
    
    log_step "Running Gitea initialization..."
    
    sudo -u www-data /usr/local/bin/gitea -c "${CONFIG_FILE}" migrate 2>&1 | grep -v "^$" || true
    
    log_success "Gitea initialization completed"
}

# Enable and start service
enable_start_service() {
    log_header "Starting Gitea Service"
    
    log_step "Reloading systemd daemon..."
    systemctl daemon-reload
    
    log_step "Enabling ${INSTANCE_NAME} service..."
    systemctl enable "${INSTANCE_NAME}"
    
    log_step "Starting ${INSTANCE_NAME} service..."
    systemctl start "${INSTANCE_NAME}"
    
    # Wait a moment for service to start
    sleep 2
    
    # Check service status
    if systemctl is-active --quiet "${INSTANCE_NAME}"; then
        log_success "Service is running"
    else
        log_error "Service failed to start. Check logs:"
        systemctl status "${INSTANCE_NAME}" || true
        journalctl -u "${INSTANCE_NAME}" -n 20 || true
        return 1
    fi
}

# Verify installation
verify_installation() {
    log_header "Verifying Installation"
    
    log_step "Checking port ${GITEA_PORT}..."
    if ss -tuln 2>/dev/null | grep -q ":${GITEA_PORT} "; then
        log_success "Gitea is listening on port ${GITEA_PORT}"
    else
        log_error "Gitea is not listening on port ${GITEA_PORT}"
        return 1
    fi
    
    log_step "Checking service status..."
    systemctl status "${INSTANCE_NAME}" --no-pager || true
}

# Display final summary
display_summary() {
    log_header "Installation Complete!"
    
    echo ""
    echo -e "${BOLD}${GREEN}Setup Summary:${NC}"
    echo ""
    
    echo -e "Instance Name:          ${BOLD}${BLUE}${INSTANCE_NAME}${NC}"
    echo -e "Running Port:           ${BOLD}${BLUE}${GITEA_PORT}${NC}"
    echo -e "Access Type:            ${BOLD}${BLUE}${GITEA_ACCESS_TYPE}${NC}"
    echo -e "Domain/IP:              ${BOLD}${BLUE}${GITEA_DOMAIN}${NC}"
    echo -e "Database Type:          ${BOLD}${BLUE}${DB_TYPE}${NC}"
    
    if [ "$DB_TYPE" = "mysql" ]; then
        echo -e "Database:               ${BOLD}${BLUE}${DB_NAME}${NC} (${DB_USER}@${DB_HOST}:${DB_PORT})"
    fi
    
    echo ""
    echo -e "${BOLD}${CYAN}Important Files:${NC}"
    echo -e "Service File:           ${BOLD}${YELLOW}${SERVICE_FILE}${NC}"
    echo -e "Config File:            ${BOLD}${YELLOW}${CONFIG_FILE}${NC}"
    echo -e "Data Directory:         ${BOLD}${YELLOW}/var/lib/${INSTANCE_NAME}${NC}"
    echo -e "Log Directory:          ${BOLD}${YELLOW}/var/lib/${INSTANCE_NAME}/log${NC}"
    
    echo ""
    echo -e "${BOLD}${GREEN}Useful Commands:${NC}"
    echo -e "  View logs:              ${BOLD}journalctl -u ${INSTANCE_NAME} -f${NC}"
    echo -e "  Stop service:           ${BOLD}systemctl stop ${INSTANCE_NAME}${NC}"
    echo -e "  Start service:          ${BOLD}systemctl start ${INSTANCE_NAME}${NC}"
    echo -e "  Restart service:        ${BOLD}systemctl restart ${INSTANCE_NAME}${NC}"
    echo -e "  Service status:         ${BOLD}systemctl status ${INSTANCE_NAME}${NC}"
    
    echo ""
    echo -e "${BOLD}${GREEN}Access URL:${NC}"
    if [ "$GITEA_ACCESS_TYPE" = "domain" ]; then
        echo -e "  ${BOLD}${BLUE}https://${GITEA_DOMAIN}${NC}"
    else
        echo -e "  ${BOLD}${BLUE}http://${GITEA_DOMAIN}:${GITEA_PORT}${NC}"
    fi
    
    echo ""
    echo -e "${BOLD}${YELLOW}⚠ Next Steps:${NC}"
    echo -e "  1. If using MySQL, configure database and user"
    echo -e "  2. Configure Cloudflare Tunnel (if using)"
    echo -e "  3. Access Gitea and complete initial setup"
    echo -e "  4. Create admin account"
    
    echo ""
}

# Main execution
main() {
    clear
    
    echo -e "${BOLD}${BLUE}"
    cat << EOF
╔═══════════════════════════════════════════════════════╗
║           Gitea Installation Script                  ║
║   Easy setup for multiple Gitea instances            ║
╚═══════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    check_root
    check_dependencies
    check_www_data_user
    
    get_postfix
    get_port
    get_domain_ip
    get_database_config
    
    download_gitea
    create_directories
    create_config
    create_systemd_service
    initialize_gitea
    enable_start_service
    verify_installation
    display_summary
    
    log_success "All done! Your Gitea instance is ready."
}

# Run main function
main "$@"
